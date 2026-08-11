import {
  ConnectedSocket,
  MessageBody,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Server, Socket } from 'socket.io';
import { PresenceService } from './presence.service';
import { CreatedServiceRequest, MatchingService } from './matching.service';
import {
  ACCEPT_TIMEOUT_MS,
  CANDIDATES_PER_ROUND,
  WAKEUP_ACCEPT_TIMEOUT_MS,
  WAKEUP_CANDIDATES,
  buildRadiusSequence,
} from './matching.constants';
import { clientRoom, craftsmanRoom } from './matching.rooms';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { User } from '../database/entities/user.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { NotificationsService } from '../firebase/notifications.service';
import { TokensService } from '../auth/tokens.service';
import { WhatsappService } from '../whatsapp/whatsapp.service';
import { resolveVerifiedAuth } from '../auth/resolve-verified-phone';

const SERVICE_CATEGORY_LABELS_FR: Record<ServiceCategory, string> = {
  [ServiceCategory.PLUMBER]: 'plomberie',
  [ServiceCategory.ELECTRICIAN]: 'électricité',
  [ServiceCategory.AC_REPAIR]: 'climatisation',
  [ServiceCategory.CLEANING]: 'ménage',
  [ServiceCategory.CARPENTER]: 'menuiserie',
  [ServiceCategory.MECHANIC]: 'mécanique',
  [ServiceCategory.PAINTER]: 'peinture',
  [ServiceCategory.ALUMINUM_WORK]: 'aluminium',
  [ServiceCategory.CAMERA_INSTALLATION]: 'installation de caméras',
  [ServiceCategory.TV_INSTALLATION]: 'installation TV',
  [ServiceCategory.SATELLITE_INSTALLATION]: 'installation satellite',
  [ServiceCategory.CONSTRUCTION]: 'construction',
  [ServiceCategory.BLACKSMITH]: 'ferronnerie',
  [ServiceCategory.HOUSEKEEPING]: 'ménage',
  [ServiceCategory.HOME_TUTORING]: 'soutien scolaire',
};

// Generic copy for the lifecycle events relayed through notifyClient/
// notifyCraftsman below — those call sites only ever have a requestId to
// hand over, no richer context, unlike request:new/request:assigned in
// runMatchingLoop which build their own richer text inline.
const CLIENT_EVENT_COPY: Record<
  | 'request:started'
  | 'request:awaiting_confirmation'
  | 'request:completed'
  | 'request:cancelled',
  { title: string; body: string }
> = {
  'request:started': {
    title: 'Votre artisan a commencé',
    body: "L'intervention est en cours.",
  },
  'request:awaiting_confirmation': {
    title: 'Mission terminée par l’artisan',
    body: 'Confirmez la fin de la mission dans l’application.',
  },
  'request:completed': {
    title: 'Mission terminée',
    body: 'Votre demande a été marquée comme terminée.',
  },
  'request:cancelled': {
    title: 'Demande annulée',
    body: "L'artisan a annulé cette demande.",
  },
};

const CRAFTSMAN_EVENT_COPY: Record<
  'request:cancelled' | 'request:completed',
  { title: string; body: string }
> = {
  'request:cancelled': {
    title: 'Demande annulée',
    body: 'Le client a annulé cette demande.',
  },
  'request:completed': {
    title: 'Mission confirmée',
    body: 'Le client a confirmé la fin de la mission.',
  },
};

function estimateArrivalMinutes(distanceMeters: number): number {
  const averageSpeedMetersPerMinute = 500; // ~30 km/h urban traffic, rough MVP heuristic
  return Math.max(1, Math.round(distanceMeters / averageSpeedMetersPerMinute));
}

interface SocketUser {
  id: string;
  role: UserRole;
}

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

@Injectable()
@WebSocketGateway({
  cors: {
    origin:
      ALLOWED_ORIGINS.length > 0
        ? ALLOWED_ORIGINS
        : process.env.NODE_ENV === 'production'
          ? false
          : '*',
  },
})
export class MatchingGateway implements OnGatewayInit, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  // One in-flight accept-wait per request at a time (radius rounds are
  // sequential), resolved by handleAccept or timed out by waitForAccept.
  // This only coordinates accepts within a single server process — the
  // Postgres WHERE status='pending' guard in tryAssign is what actually
  // makes assignment safe if this ever runs behind multiple instances.
  private readonly acceptResolvers = new Map<
    string,
    (craftsmanId: string) => void
  >();

  // Which client is waiting on which craftsman right now (assigned or
  // in_progress) — lets handleCraftsmanLocation relay position updates to
  // the right client room without a DB lookup on every ping. Same
  // single-process caveat as acceptResolvers above.
  private readonly activeAssignments = new Map<string, string>();

  // Requests abortMatchingLoop has flagged — checked at the top of every
  // round in runMatchingLoop so a cancelled request stops pushing to
  // candidates immediately instead of quietly running out its ~4 minute
  // worst case (see abortMatchingLoop below for why the DB status flip
  // alone doesn't stop the in-flight loop).
  private readonly cancelledRequestIds = new Set<string>();

  constructor(
    private readonly matchingService: MatchingService,
    private readonly presenceService: PresenceService,
    private readonly tokensService: TokensService,
    private readonly whatsapp: WhatsappService,
    private readonly notificationsService: NotificationsService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
  ) {}

  // Every socket must prove who it is before any handler runs — otherwise a
  // client could claim to be any clientId/craftsmanId in its message bodies.
  // Mirrors AccessTokenGuard/AuthGuard's HTTP logic (same resolveVerifiedAuth
  // helper), just reading handshake.auth instead of headers, since a plain
  // socket.io connection has no per-message Authorization header.
  afterInit(server: Server): void {
    server.use((socket, next) => {
      const token = socket.handshake.auth?.['token'] as string | undefined;
      const devPhone = socket.handshake.auth?.['devPhone'] as
        string | undefined;

      resolveVerifiedAuth(this.tokensService, this.whatsapp, token, devPhone)
        .then(({ phone, userId }) =>
          // Same id-vs-phone rationale as AuthGuard: a real token's userId
          // is authoritative and immune to phone-reuse after a deletion;
          // the dev-bypass path has no signed id, so it falls back to phone.
          userId
            ? this.userRepository.findOne({
                where: { id: userId, deletedAt: IsNull() },
              })
            : this.userRepository.findOne({ where: { phone } }),
        )
        .then((user) => {
          if (!user) {
            next(new Error('No account for this phone number'));
            return;
          }
          (socket.data as { user?: SocketUser }).user = {
            id: user.id,
            role: user.role,
          };
          next();
        })
        .catch((error: unknown) => {
          next(error instanceof Error ? error : new Error('Unauthorized'));
        });
    });
  }

  @SubscribeMessage('client:join')
  async handleClientJoin(@ConnectedSocket() client: Socket) {
    const user = this.requireUser(client);
    if (user.role !== UserRole.CLIENT) return;
    void client.join(clientRoom(user.id));
    await this.presenceService.setClientOnline(user.id);
  }

  @SubscribeMessage('craftsman:online')
  async handleCraftsmanOnline(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: {
      serviceCategory: ServiceCategory;
      latitude: number;
      longitude: number;
    },
  ) {
    const user = this.requireUser(client);
    if (user.role !== UserRole.CRAFTSMAN) return;
    const wentOnline = await this.presenceService.setOnline(
      user.id,
      body.serviceCategory,
      body.longitude,
      body.latitude,
    );
    // Deactivated by an admin — never join the room or enter presence, so
    // this craftsman can't be matched to anything.
    if (!wentOnline) return;
    void client.join(craftsmanRoom(user.id));

    const pending = await this.matchingService.findPendingNear(
      body.serviceCategory,
      body.longitude,
      body.latitude,
    );
    for (const request of pending) {
      this.server.to(craftsmanRoom(user.id)).emit('request:new', {
        requestId: request.id,
        serviceCategory: body.serviceCategory,
        distanceMeters: Math.round(request.distanceMeters),
        estimatedArrivalMinutes: estimateArrivalMinutes(request.distanceMeters),
      });
    }
  }

  @SubscribeMessage('craftsman:location')
  async handleCraftsmanLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: {
      latitude: number;
      longitude: number;
    },
  ) {
    const user = this.requireUser(client);
    if (user.role !== UserRole.CRAFTSMAN) return;
    await this.presenceService.updateLocation(
      user.id,
      body.longitude,
      body.latitude,
    );

    const clientId = this.activeAssignments.get(user.id);
    if (clientId) {
      this.server.to(clientRoom(clientId)).emit('craftsman:location:update', {
        latitude: body.latitude,
        longitude: body.longitude,
      });
    }
  }

  @SubscribeMessage('craftsman:offline')
  async handleCraftsmanOffline(@ConnectedSocket() client: Socket) {
    const user = this.requireUser(client);
    if (user.role !== UserRole.CRAFTSMAN) return;
    await this.presenceService.setOffline(user.id);
  }

  // Without this, a craftsman whose socket drops without emitting
  // craftsman:offline first (app killed, backgrounded and OS-suspended,
  // network loss) stays in the Redis presence GEO index forever — Redis has
  // no TTL on these keys. runMatchingLoop then "finds" them as a candidate,
  // emits into an empty room, and burns a full ACCEPT_TIMEOUT_MS round for
  // nobody, every round, until the request expires with no craftsman ever
  // actually notified. Same staleness risk for a client's online_clients
  // set membership, just with a lower-stakes consequence (a stale "online"
  // badge on the admin directory, nothing matching-critical).
  async handleDisconnect(client: Socket): Promise<void> {
    const user = (client.data as { user?: SocketUser }).user;
    if (!user) return;
    if (user.role === UserRole.CRAFTSMAN) {
      await this.presenceService.setOffline(user.id);
    } else {
      await this.presenceService.setClientOffline(user.id);
    }
  }

  @SubscribeMessage('request:accept')
  handleAccept(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { requestId: string },
  ) {
    const user = this.requireUser(client);
    if (user.role !== UserRole.CRAFTSMAN) return;
    const resolve = this.acceptResolvers.get(body.requestId);
    resolve?.(user.id);
  }

  // Called by MatchingController right after a cancel (client or craftsman
  // side) succeeds, so runMatchingLoop notices and stops on its own instead
  // of continuing to push request:new/notifications to candidates for a
  // request nobody's waiting on anymore. Wakes an in-flight waitForAccept
  // immediately (an empty craftsmanId resolves it the same way a timeout
  // would — falsy, so the caller treats it as "nobody accepted") rather than
  // leaving it to time out on its own; the flag itself covers the loop
  // between rounds, where no waitForAccept is currently pending. Self-clears
  // after the loop's own worst-case duration in case cancellation lands
  // after the loop already returned (e.g. cancelling a request that was
  // already 'assigned') and so never reaches the check that would delete it.
  abortMatchingLoop(requestId: string): void {
    this.cancelledRequestIds.add(requestId);
    setTimeout(
      () => this.cancelledRequestIds.delete(requestId),
      buildRadiusSequence().length * ACCEPT_TIMEOUT_MS +
        WAKEUP_ACCEPT_TIMEOUT_MS,
    );
    this.acceptResolvers.get(requestId)?.('');
  }

  private requireUser(client: Socket): SocketUser {
    const user = (client.data as { user?: SocketUser }).user;
    if (!user) {
      throw new Error('Socket connected without passing auth middleware');
    }
    return user;
  }

  // Used by MatchingController after a job-lifecycle transition (start/
  // complete/cancel). No mobile client on the Client side listens to these
  // yet — this exists so the wiring is already in place once that app does.
  notifyClient(
    clientId: string,
    event:
      | 'request:started'
      | 'request:awaiting_confirmation'
      | 'request:completed'
      | 'request:cancelled',
    payload: { requestId: string },
  ): void {
    this.server.to(clientRoom(clientId)).emit(event, payload);
    void this.notificationsService.sendToUser(
      clientId,
      CLIENT_EVENT_COPY[event],
      { event, requestId: payload.requestId },
    );
  }

  // Stops relaying this craftsman's location once their job wraps up
  // (completed/cancelled) — called by MatchingController alongside notifyClient.
  clearActiveAssignment(craftsmanId: string): void {
    this.activeAssignments.delete(craftsmanId);
  }

  // The craftsman-facing counterpart to notifyClient — used both when the
  // *client* cancels a job the craftsman had already been assigned to (so
  // the craftsman's app can drop it instead of sitting on a job that's
  // quietly dead server-side), and when the client confirms completion of a
  // job the craftsman already marked done.
  notifyCraftsman(
    craftsmanId: string,
    event: 'request:cancelled' | 'request:completed',
    payload: { requestId: string },
  ): void {
    this.server.to(craftsmanRoom(craftsmanId)).emit(event, payload);
    void this.notificationsService.sendToUser(
      craftsmanId,
      CRAFTSMAN_EVENT_COPY[event],
      { event, requestId: payload.requestId },
    );
  }

  // Fire-and-forget from the controller: the HTTP response returns as soon as
  // the request row exists, and this loop runs independently, pushing
  // updates over sockets as candidates are broadcast to / assigned / expired.
  async runMatchingLoop(request: CreatedServiceRequest): Promise<void> {
    // Everyone ever pushed to across every live round — excluded from the
    // wake-up phase's query below so nobody who already had a live shot
    // (and either declined or went quiet) gets double-pushed.
    const triedCraftsmanIds = new Set<string>();

    for (const radius of buildRadiusSequence()) {
      if (this.cancelledRequestIds.delete(request.id)) return;

      await this.matchingService.updateSearchRadius(request.id, radius);

      const candidates = await this.presenceService.findNearest(
        request.serviceCategory,
        request.longitude,
        request.latitude,
        radius,
        CANDIDATES_PER_ROUND,
      );
      for (const candidate of candidates) {
        triedCraftsmanIds.add(candidate.craftsmanId);
      }

      // Deliberately not skipping the wait when candidates.length === 0:
      // this round's ACCEPT_TIMEOUT_MS is also the window during which a
      // craftsman who logs in / goes available mid-round gets caught by
      // handleCraftsmanOnline's findPendingNear catch-up and can still tap
      // accept against this same waitForAccept. Bailing out early here would
      // make a request with nobody currently online expire in milliseconds,
      // leaving no realistic window for a craftsman arriving moments later.
      for (const candidate of candidates) {
        this.server
          .to(craftsmanRoom(candidate.craftsmanId))
          .emit('request:new', {
            requestId: request.id,
            serviceCategory: request.serviceCategory,
            distanceMeters: Math.round(candidate.distanceMeters),
            estimatedArrivalMinutes: estimateArrivalMinutes(
              candidate.distanceMeters,
            ),
          });
        void this.notificationsService.sendToUser(
          candidate.craftsmanId,
          {
            title: 'Nouvelle demande',
            body: `Une demande de ${SERVICE_CATEGORY_LABELS_FR[request.serviceCategory]} à ${(candidate.distanceMeters / 1000).toFixed(1)} km de vous.`,
          },
          { event: 'request:new', requestId: request.id },
        );
      }

      const acceptedCraftsmanId = await this.waitForAccept(
        request.id,
        ACCEPT_TIMEOUT_MS,
      );

      if (acceptedCraftsmanId) {
        const won = await this.assignAndNotify(
          request,
          acceptedCraftsmanId,
          candidates.map((candidate) => candidate.craftsmanId),
        );
        if (won) return;
      }

      for (const candidate of candidates) {
        this.server
          .to(craftsmanRoom(candidate.craftsmanId))
          .emit('request:unavailable', { requestId: request.id });
      }
    }

    // Fallback for the common early-stage-marketplace case: zero craftsmen
    // currently hold a live socket in Redis (app backgrounded/killed), but at
    // least one has a last-known Postgres location on file. Push a
    // notification so their app cold-opens; CraftsmanHomeController's
    // _goOnlineFromGps runs unconditionally on every load, which
    // re-establishes the socket, calls craftsman:online, and
    // handleCraftsmanOnline's existing findPendingNear catch-up re-emits
    // request:new for this still-pending request with zero new code on that
    // path. Their subsequent request:accept resolves this very waitForAccept
    // call via the same requestId — no new accept mechanism needed.
    if (this.cancelledRequestIds.delete(request.id)) return;

    const wakeupCandidates =
      await this.matchingService.findNearestByLastKnownLocation(
        request.serviceCategory,
        request.longitude,
        request.latitude,
        Array.from(triedCraftsmanIds),
        WAKEUP_CANDIDATES,
      );

    if (wakeupCandidates.length > 0) {
      for (const candidate of wakeupCandidates) {
        void this.notificationsService.sendToUser(
          candidate.craftsmanId,
          {
            title: 'Nouvelle demande à proximité',
            body: `Une demande de ${SERVICE_CATEGORY_LABELS_FR[request.serviceCategory]} à ${(candidate.distanceMeters / 1000).toFixed(1)} km de vous. Ouvrez l'application pour l'accepter.`,
          },
          { event: 'request:new', requestId: request.id },
        );
      }

      const wakeupAcceptedCraftsmanId = await this.waitForAccept(
        request.id,
        WAKEUP_ACCEPT_TIMEOUT_MS,
      );
      if (wakeupAcceptedCraftsmanId) {
        const won = await this.assignAndNotify(
          request,
          wakeupAcceptedCraftsmanId,
          wakeupCandidates.map((candidate) => candidate.craftsmanId),
        );
        if (won) return;
      }
    }

    const expired = await this.matchingService.expireRequest(request.id);
    if (expired) {
      this.server
        .to(clientRoom(request.clientId))
        .emit('request:no_craftsman_available', { requestId: request.id });
      void this.notificationsService.sendToUser(
        request.clientId,
        {
          title: 'Aucun artisan disponible',
          body: "Nous n'avons trouvé aucun artisan disponible pour le moment.",
        },
        { event: 'request:no_craftsman_available', requestId: request.id },
      );
    }
  }

  // Shared by both the radius-round win path and the wake-up-phase win path:
  // once a craftsman's accept resolves tryAssign's compare-and-swap, the
  // notify-winner/notify-client/notify-losers sequence is identical
  // regardless of which mechanism (live round vs. wake-up push) got them
  // there.
  private async assignAndNotify(
    request: CreatedServiceRequest,
    acceptedCraftsmanId: string,
    otherCandidateIds: string[],
  ): Promise<boolean> {
    const assigned = await this.matchingService.tryAssign(
      request.id,
      acceptedCraftsmanId,
    );
    if (!assigned) return false;

    const craftsman = await this.userRepository.findOne({
      where: { id: acceptedCraftsmanId },
    });
    this.activeAssignments.set(acceptedCraftsmanId, request.clientId);
    this.server.to(clientRoom(request.clientId)).emit('request:assigned', {
      requestId: request.id,
      craftsmanId: acceptedCraftsmanId,
      craftsmanFullName: craftsman?.fullName ?? null,
      craftsmanPhone: craftsman?.phone ?? null,
    });
    void this.notificationsService.sendToUser(
      request.clientId,
      {
        title: 'Artisan trouvé',
        body: craftsman?.fullName
          ? `${craftsman.fullName} arrive pour votre demande.`
          : 'Un artisan a accepté votre demande.',
      },
      { event: 'request:assigned', requestId: request.id },
    );
    // The winning craftsman otherwise gets no confirmation at all — every
    // *other* candidate gets `request:unavailable` below, but without this,
    // whoever actually won the accept race has no way to know their tap
    // succeeded versus the request having simply gone quiet.
    this.server
      .to(craftsmanRoom(acceptedCraftsmanId))
      .emit('request:assigned', { requestId: request.id });
    void this.notificationsService.sendToUser(
      acceptedCraftsmanId,
      {
        title: 'Demande acceptée',
        body: 'Vous avez remporté cette demande. Rendez-vous sur les lieux.',
      },
      { event: 'request:assigned', requestId: request.id },
    );
    for (const otherId of otherCandidateIds) {
      if (otherId !== acceptedCraftsmanId) {
        this.server
          .to(craftsmanRoom(otherId))
          .emit('request:unavailable', { requestId: request.id });
      }
    }
    return true;
  }

  private waitForAccept(
    requestId: string,
    timeoutMs: number,
  ): Promise<string | null> {
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        this.acceptResolvers.delete(requestId);
        resolve(null);
      }, timeoutMs);

      this.acceptResolvers.set(requestId, (craftsmanId: string) => {
        clearTimeout(timer);
        this.acceptResolvers.delete(requestId);
        resolve(craftsmanId);
      });
    });
  }
}
