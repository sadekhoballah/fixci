import {
  ConnectedSocket,
  MessageBody,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Server, Socket } from 'socket.io';
import { PresenceService } from './presence.service';
import { CreatedServiceRequest, MatchingService } from './matching.service';
import {
  CANDIDATES_PER_STEP,
  DispatchStep,
  MATCHING_WINDOW_MS,
  WAKEUP_CANDIDATES_PER_STEP,
  buildDispatchSchedule,
  isTightRadiusCategory,
  worstCaseLoopDurationMs,
} from './matching.constants';
import { clientRoom, craftsmanRoom } from './matching.rooms';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { User } from '../database/entities/user.entity';
import { UserRole } from '../database/enums/user-role.enum';
import {
  NotificationsService,
  PushNotificationContent,
} from '../firebase/notifications.service';
import { TokensService } from '../auth/tokens.service';
import { resolveVerifiedAuth } from '../auth/resolve-verified-phone';
import { SafetyService } from '../safety/safety.service';

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
  [ServiceCategory.GARDENER]: 'jardinage',
  [ServiceCategory.TAXI]: 'taxi',
  [ServiceCategory.CAMION]: 'camion',
  [ServiceCategory.OTHER_TRADE]: 'autre métier',
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
export class MatchingGateway
  implements OnGatewayInit, OnGatewayDisconnect, OnApplicationBootstrap
{
  private readonly logger = new Logger(MatchingGateway.name);

  @WebSocketServer()
  server: Server;

  // One accept-wait per in-flight request, open for its whole matching
  // window — resolved by handleAccept, by abortMatchingLoop, or by the
  // window closing (see openAcceptWindow).
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

  // Requests abortMatchingLoop has flagged — checked before every dispatch
  // step in runMatchingLoop so a cancelled request stops pushing to
  // candidates immediately instead of running out its window (see
  // abortMatchingLoop below for why the DB status flip alone doesn't stop
  // the in-flight loop).
  private readonly cancelledRequestIds = new Set<string>();

  // Per in-flight search: when its window closes, and every craftsman an
  // offer went out to — live candidates, wake-up pushes, and late joiners
  // picked up by handleCraftsmanOnline — so they all get request:unavailable
  // when it ends, and a late joiner's card counts down to the real deadline.
  // Same single-process caveat as acceptResolvers above.
  private readonly activeSearches = new Map<
    string,
    { deadline: number; offeredTo: Set<string> }
  >();

  constructor(
    private readonly matchingService: MatchingService,
    private readonly presenceService: PresenceService,
    private readonly tokensService: TokensService,
    private readonly notificationsService: NotificationsService,
    private readonly safetyService: SafetyService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
  ) {}

  // The matching loop lives only in this process's memory: anything still
  // 'pending' at startup lost its loop when the previous process stopped
  // (every deploy restarts it) and would otherwise block its client from
  // creating a new request forever. See expireOrphanedPendingRequests.
  async onApplicationBootstrap(): Promise<void> {
    const expired = await this.matchingService.expireOrphanedPendingRequests();
    if (expired > 0) {
      this.logger.warn(
        `Expired ${expired} pending request(s) orphaned by the restart`,
      );
    }
  }

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

      resolveVerifiedAuth(this.tokensService, token, devPhone)
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
      // No live search behind it (orphaned — see onApplicationBootstrap):
      // an accept would go nowhere.
      const search = this.activeSearches.get(request.id);
      if (!search) continue;
      if (
        await this.safetyService.isBlockedEitherWay(user.id, request.clientId)
      ) {
        continue;
      }
      search.offeredTo.add(user.id);
      this.server.to(craftsmanRoom(user.id)).emit(
        'request:new',
        this.offerPayload(
          {
            id: request.id,
            serviceCategory: body.serviceCategory,
            destinationAddress: request.destinationAddress,
            loadDetails: request.loadDetails,
          },
          request.distanceMeters,
          search.deadline,
        ),
      );
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
  // emits into an empty room, and wastes one of the step's candidate slots
  // on nobody, every request, until the stale entry goes away. Same staleness risk for a client's online_clients
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
  // request nobody's waiting on anymore. Settles the open accept window
  // immediately (an empty craftsmanId is falsy, like the window closing)
  // so the loop withdraws every outstanding offer at once rather than
  // leaving cards up until the 75s run out; the flag is what tells it this
  // was a cancellation rather than "nobody accepted". Self-clears
  // after the loop's own worst-case duration in case cancellation lands
  // after the loop already returned (e.g. cancelling a request that was
  // already 'assigned') and so never reaches the check that would delete it.
  abortMatchingLoop(requestId: string): void {
    this.cancelledRequestIds.add(requestId);
    setTimeout(
      () => this.cancelledRequestIds.delete(requestId),
      worstCaseLoopDurationMs(),
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

  // Generic counterpart to notifyClient/notifyCraftsman, for callers (e.g.
  // MissionsService/AdminService) that only have a bare userId and must work
  // for either role, since Missions/Freelance is symmetric — a client and a
  // craftsman use the exact same notification path. Looks the role up once,
  // then reuses the same mandatory dual-path (socket + push) pattern as
  // every other notify* method here. Silently no-ops if the user doesn't
  // exist (deleted between the triggering action and this call).
  async notifyUser(
    userId: string,
    event: string,
    payload: Record<string, unknown>,
    push: PushNotificationContent,
  ): Promise<void> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) return;
    const room =
      user.role === UserRole.CRAFTSMAN
        ? craftsmanRoom(userId)
        : clientRoom(userId);
    this.server.to(room).emit(event, payload);
    void this.notificationsService.sendToUser(userId, push, {
      event,
      ...Object.fromEntries(
        Object.entries(payload).map(([key, value]) => [key, String(value)]),
      ),
    });
  }

  // Fire-and-forget from the controller: the HTTP response returns as soon as
  // the request row exists, and this loop runs independently, pushing
  // updates over sockets as candidates are offered / assigned / expired.
  //
  // One MATCHING_WINDOW_MS (75s) window per request. Dispatch steps (see
  // buildDispatchSchedule) add candidates as it goes — nearest 5 within 5km
  // straight away, the next 5 within 10km at 35s — but no offer is ever
  // withdrawn before the window closes: the nearest craftsmen get the full
  // 75s to respond. First accept wins (tryAssign's compare-and-swap). If
  // nobody accepts, the request expires and the client app fetches the
  // nearest craftsmen to contact directly (FallbackContactsService).
  async runMatchingLoop(request: CreatedServiceRequest): Promise<void> {
    const startedAt = Date.now();
    const deadline = startedAt + MATCHING_WINDOW_MS;
    // Everyone an offer went out to — never offered twice, and all told
    // request:unavailable once the search ends.
    const offeredTo = new Set<string>();
    this.activeSearches.set(request.id, { deadline, offeredTo });
    try {
      // Fetched once per request — a block can't change mid-search. See
      // UserBlock's class-level comment for why this is bidirectional.
      const blockedCraftsmanIds =
        await this.safetyService.getBlockedCounterpartIds(request.clientId);
      const acceptance = this.openAcceptWindow(
        request.id,
        deadline - Date.now(),
      );

      for (const step of buildDispatchSchedule(request.serviceCategory)) {
        const settledEarly = await this.settlesWithin(
          acceptance,
          startedAt + step.atMs - Date.now(),
        );
        if (settledEarly || this.cancelledRequestIds.has(request.id)) break;
        await this.dispatchStep(
          request,
          step,
          offeredTo,
          blockedCraftsmanIds,
          deadline,
        );
      }

      const acceptedCraftsmanId = await acceptance;
      if (this.cancelledRequestIds.delete(request.id)) {
        this.withdrawOffers(request.id, offeredTo);
        return;
      }
      if (acceptedCraftsmanId) {
        // Losing tryAssign means the request already left 'pending' (the
        // client cancelled in the same instant) — nothing left to match.
        const won = await this.assignAndNotify(request, acceptedCraftsmanId, [
          ...offeredTo,
        ]);
        if (!won) this.withdrawOffers(request.id, offeredTo);
        return;
      }
      this.withdrawOffers(request.id, offeredTo);
      await this.expireAndNotify(request);
    } finally {
      this.activeSearches.delete(request.id);
    }
  }

  // One dispatch step: the nearest live candidates within the step's radius
  // that haven't had this offer yet, plus (regular trades only — see
  // TIGHT_RADIUS_CATEGORIES) a wake-up push to the nearest craftsmen who
  // aren't live right now but were last seen within that radius.
  private async dispatchStep(
    request: CreatedServiceRequest,
    step: DispatchStep,
    offeredTo: Set<string>,
    blockedCraftsmanIds: Set<string>,
    deadline: number,
  ): Promise<void> {
    await this.matchingService.updateSearchRadius(
      request.id,
      step.radiusMeters,
    );
    const categoryLabel = SERVICE_CATEGORY_LABELS_FR[request.serviceCategory];
    const offer = (distanceMeters: number) =>
      this.offerPayload(request, distanceMeters, deadline);

    // Over-fetch by everyone already offered/blocked, since Redis returns
    // the nearest N regardless and those get filtered out here.
    const live = (
      await this.presenceService.findNearest(
        request.serviceCategory,
        request.longitude,
        request.latitude,
        step.radiusMeters,
        CANDIDATES_PER_STEP + offeredTo.size + blockedCraftsmanIds.size,
      )
    )
      .filter(
        (candidate) =>
          !offeredTo.has(candidate.craftsmanId) &&
          !blockedCraftsmanIds.has(candidate.craftsmanId),
      )
      .slice(0, CANDIDATES_PER_STEP);
    for (const candidate of live) {
      offeredTo.add(candidate.craftsmanId);
      this.server
        .to(craftsmanRoom(candidate.craftsmanId))
        .emit('request:new', offer(candidate.distanceMeters));
      const km = (candidate.distanceMeters / 1000).toFixed(1);
      void this.notificationsService.sendToUser(
        candidate.craftsmanId,
        {
          title: 'Nouvelle demande',
          body: request.destinationAddress
            ? `Une demande de ${categoryLabel} à ${km} km de vous → destination : ${request.destinationAddress}`
            : `Une demande de ${categoryLabel} à ${km} km de vous.`,
        },
        { event: 'request:new', requestId: request.id },
        { ringUntil: new Date(deadline) },
      );
    }

    if (isTightRadiusCategory(request.serviceCategory)) return;
    const sleeping = await this.matchingService.findNearestByLastKnownLocation(
      request.serviceCategory,
      request.longitude,
      request.latitude,
      [...offeredTo, ...blockedCraftsmanIds],
      WAKEUP_CANDIDATES_PER_STEP,
      step.radiusMeters,
    );
    for (const candidate of sleeping) {
      offeredTo.add(candidate.craftsmanId);
      // Also over the socket: "not among the nearest live 5" doesn't mean
      // offline — someone further down the live list with the app open
      // should see the card straight away rather than only the push.
      this.server
        .to(craftsmanRoom(candidate.craftsmanId))
        .emit('request:new', offer(candidate.distanceMeters));
      void this.notificationsService.sendToUser(
        candidate.craftsmanId,
        {
          title: 'Nouvelle demande à proximité',
          body: `Une demande de ${categoryLabel} à ${(candidate.distanceMeters / 1000).toFixed(1)} km de vous. Ouvrez l'application dans la minute pour l'accepter.`,
        },
        { event: 'request:new', requestId: request.id },
        { ringUntil: new Date(deadline) },
      );
    }
  }

  // The request:new payload. respondWithinSeconds/expiresAt let the
  // craftsman app count down to this offer's real deadline — app builds
  // from before the 75s window ignore them and keep their fixed 18s.
  private offerPayload(
    request: Pick<
      CreatedServiceRequest,
      'id' | 'serviceCategory' | 'destinationAddress' | 'loadDetails'
    >,
    distanceMeters: number,
    deadline: number,
  ) {
    return {
      requestId: request.id,
      serviceCategory: request.serviceCategory,
      distanceMeters: Math.round(distanceMeters),
      estimatedArrivalMinutes: estimateArrivalMinutes(distanceMeters),
      destinationAddress: request.destinationAddress,
      loadDetails: request.loadDetails,
      respondWithinSeconds: Math.max(
        0,
        Math.floor((deadline - Date.now()) / 1000),
      ),
      expiresAt: new Date(deadline).toISOString(),
    };
  }

  private withdrawOffers(requestId: string, craftsmanIds: Set<string>): void {
    for (const craftsmanId of craftsmanIds) {
      this.server
        .to(craftsmanRoom(craftsmanId))
        .emit('request:unavailable', { requestId });
    }
    void this.notificationsService.cancelRing([...craftsmanIds], requestId);
  }

  // The client app reacts to request:no_craftsman_available by fetching the
  // nearest craftsmen to contact directly (GET /matching/requests/:id/
  // fallback-craftsmen) — the push copy stays generic enough for app builds
  // from before that list existed.
  private async expireAndNotify(request: CreatedServiceRequest): Promise<void> {
    const expired = await this.matchingService.expireRequest(request.id);
    if (expired) {
      this.server
        .to(clientRoom(request.clientId))
        .emit('request:no_craftsman_available', { requestId: request.id });
      void this.notificationsService.sendToUser(
        request.clientId,
        {
          title: "Aucun artisan n'a accepté à temps",
          body: 'Ouvrez Fix Pro pour trouver un artisan proche de vous.',
        },
        { event: 'request:no_craftsman_available', requestId: request.id },
      );
    }
  }

  // Once a craftsman's accept resolves tryAssign's compare-and-swap:
  // notify the winner, the client, and everyone else who had the offer.
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
    // The winner too: they may have accepted from the app without touching
    // the notification, which would otherwise keep ringing.
    void this.notificationsService.cancelRing(otherCandidateIds, request.id);
    return true;
  }

  // Resolves with the accepting craftsman's id, '' if abortMatchingLoop
  // cancelled the search, or null once the window closes.
  private openAcceptWindow(
    requestId: string,
    windowMs: number,
  ): Promise<string | null> {
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        this.acceptResolvers.delete(requestId);
        resolve(null);
      }, windowMs);

      this.acceptResolvers.set(requestId, (craftsmanId: string) => {
        clearTimeout(timer);
        this.acceptResolvers.delete(requestId);
        resolve(craftsmanId);
      });
    });
  }

  // Waits up to `ms` for `acceptance` to settle; true if it did (accepted,
  // cancelled or closed), false if the time ran out first.
  private settlesWithin(
    acceptance: Promise<string | null>,
    ms: number,
  ): Promise<boolean> {
    if (ms <= 0) return Promise.resolve(false);
    return new Promise((resolve) => {
      const timer = setTimeout(() => resolve(false), ms);
      void acceptance.then(() => {
        clearTimeout(timer);
        resolve(true);
      });
    });
  }
}
