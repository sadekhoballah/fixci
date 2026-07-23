import {
  ConnectedSocket,
  MessageBody,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Server, Socket } from 'socket.io';
import { PresenceService } from './presence.service';
import { CreatedServiceRequest, MatchingService } from './matching.service';
import {
  ACCEPT_TIMEOUT_MS,
  CANDIDATES_PER_ROUND,
  buildRadiusSequence,
} from './matching.constants';
import { clientRoom, craftsmanRoom } from './matching.rooms';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { User } from '../database/entities/user.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { PhoneTokenVerifierService } from '../firebase/phone-token-verifier.service';
import { resolveVerifiedPhone } from '../auth/resolve-verified-phone';

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
export class MatchingGateway implements OnGatewayInit {
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

  constructor(
    private readonly matchingService: MatchingService,
    private readonly presenceService: PresenceService,
    private readonly phoneTokenVerifier: PhoneTokenVerifierService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
  ) {}

  // Every socket must prove who it is before any handler runs — otherwise a
  // client could claim to be any clientId/craftsmanId in its message bodies.
  // Mirrors FirebaseAuthGuard/AuthGuard's HTTP logic (same resolveVerifiedPhone
  // helper), just reading handshake.auth instead of headers, since a plain
  // socket.io connection has no per-message Authorization header.
  afterInit(server: Server): void {
    server.use((socket, next) => {
      const token = socket.handshake.auth?.['token'] as string | undefined;
      const devPhone = socket.handshake.auth?.['devPhone'] as
        string | undefined;

      resolveVerifiedPhone(this.phoneTokenVerifier, token, devPhone)
        .then((phone) => this.userRepository.findOne({ where: { phone } }))
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
  handleClientJoin(@ConnectedSocket() client: Socket) {
    const user = this.requireUser(client);
    if (user.role !== UserRole.CLIENT) return;
    void client.join(clientRoom(user.id));
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
    void client.join(craftsmanRoom(user.id));
    await this.presenceService.setOnline(
      user.id,
      body.serviceCategory,
      body.longitude,
      body.latitude,
    );
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
    event: 'request:started' | 'request:completed' | 'request:cancelled',
    payload: { requestId: string },
  ): void {
    this.server.to(clientRoom(clientId)).emit(event, payload);
  }

  // Stops relaying this craftsman's location once their job wraps up
  // (completed/cancelled) — called by MatchingController alongside notifyClient.
  clearActiveAssignment(craftsmanId: string): void {
    this.activeAssignments.delete(craftsmanId);
  }

  // Fire-and-forget from the controller: the HTTP response returns as soon as
  // the request row exists, and this loop runs independently, pushing
  // updates over sockets as candidates are broadcast to / assigned / expired.
  async runMatchingLoop(request: CreatedServiceRequest): Promise<void> {
    for (const radius of buildRadiusSequence()) {
      await this.matchingService.updateSearchRadius(request.id, radius);

      const candidates = await this.presenceService.findNearest(
        request.serviceCategory,
        request.longitude,
        request.latitude,
        radius,
        CANDIDATES_PER_ROUND,
      );

      if (candidates.length === 0) continue;

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
      }

      const acceptedCraftsmanId = await this.waitForAccept(
        request.id,
        ACCEPT_TIMEOUT_MS,
      );

      if (acceptedCraftsmanId) {
        const assigned = await this.matchingService.tryAssign(
          request.id,
          acceptedCraftsmanId,
        );
        if (assigned) {
          const craftsman = await this.userRepository.findOne({
            where: { id: acceptedCraftsmanId },
          });
          this.activeAssignments.set(acceptedCraftsmanId, request.clientId);
          this.server
            .to(clientRoom(request.clientId))
            .emit('request:assigned', {
              requestId: request.id,
              craftsmanId: acceptedCraftsmanId,
              craftsmanFullName: craftsman?.fullName ?? null,
              craftsmanPhone: craftsman?.phone ?? null,
            });
          // The winning craftsman otherwise gets no confirmation at all —
          // every *other* candidate in this round gets `request:unavailable`
          // below, but without this, whoever actually won the accept race
          // has no way to know their tap succeeded versus the request
          // having simply gone quiet.
          this.server
            .to(craftsmanRoom(acceptedCraftsmanId))
            .emit('request:assigned', { requestId: request.id });
          for (const candidate of candidates) {
            if (candidate.craftsmanId !== acceptedCraftsmanId) {
              this.server
                .to(craftsmanRoom(candidate.craftsmanId))
                .emit('request:unavailable', { requestId: request.id });
            }
          }
          return;
        }
      }

      for (const candidate of candidates) {
        this.server
          .to(craftsmanRoom(candidate.craftsmanId))
          .emit('request:unavailable', { requestId: request.id });
      }
    }

    const expired = await this.matchingService.expireRequest(request.id);
    if (expired) {
      this.server
        .to(clientRoom(request.clientId))
        .emit('request:no_craftsman_available', { requestId: request.id });
    }
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
