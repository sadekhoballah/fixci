import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
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

function estimateArrivalMinutes(distanceMeters: number): number {
  const averageSpeedMetersPerMinute = 500; // ~30 km/h urban traffic, rough MVP heuristic
  return Math.max(1, Math.round(distanceMeters / averageSpeedMetersPerMinute));
}

@WebSocketGateway({ cors: { origin: '*' } })
export class MatchingGateway {
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

  constructor(
    private readonly matchingService: MatchingService,
    private readonly presenceService: PresenceService,
  ) {}

  @SubscribeMessage('client:join')
  handleClientJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { clientId: string },
  ) {
    void client.join(clientRoom(body.clientId));
  }

  @SubscribeMessage('craftsman:online')
  async handleCraftsmanOnline(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: {
      craftsmanId: string;
      serviceCategory: ServiceCategory;
      latitude: number;
      longitude: number;
    },
  ) {
    void client.join(craftsmanRoom(body.craftsmanId));
    await this.presenceService.setOnline(
      body.craftsmanId,
      body.serviceCategory,
      body.longitude,
      body.latitude,
    );
  }

  @SubscribeMessage('craftsman:location')
  async handleCraftsmanLocation(
    @MessageBody()
    body: {
      craftsmanId: string;
      latitude: number;
      longitude: number;
    },
  ) {
    await this.presenceService.updateLocation(
      body.craftsmanId,
      body.longitude,
      body.latitude,
    );
  }

  @SubscribeMessage('craftsman:offline')
  async handleCraftsmanOffline(@MessageBody() body: { craftsmanId: string }) {
    await this.presenceService.setOffline(body.craftsmanId);
  }

  @SubscribeMessage('request:accept')
  handleAccept(
    @MessageBody() body: { requestId: string; craftsmanId: string },
  ) {
    const resolve = this.acceptResolvers.get(body.requestId);
    resolve?.(body.craftsmanId);
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
          this.server
            .to(clientRoom(request.clientId))
            .emit('request:assigned', {
              requestId: request.id,
              craftsmanId: acceptedCraftsmanId,
            });
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
