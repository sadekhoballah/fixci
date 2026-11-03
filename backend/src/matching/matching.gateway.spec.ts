import { MatchingGateway } from './matching.gateway';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { CreatedServiceRequest } from './matching.service';

type Emit = { room: string; event: string; payload: Record<string, unknown> };

// Drives runMatchingLoop with fake timers through its 75s window — every
// collaborator is a stub, the socket server just records emits per room.
describe('MatchingGateway.runMatchingLoop', () => {
  let gateway: MatchingGateway;
  let emits: Emit[];
  let matchingService: {
    updateSearchRadius: jest.Mock;
    findNearestByLastKnownLocation: jest.Mock;
    tryAssign: jest.Mock;
    expireRequest: jest.Mock;
  };
  let presenceService: { findNearest: jest.Mock };
  let notificationsService: { sendToUser: jest.Mock; cancelRing: jest.Mock };

  const request = (
    serviceCategory = ServiceCategory.ELECTRICIAN,
  ): CreatedServiceRequest => ({
    id: 'req-1',
    clientId: 'client-1',
    serviceCategory,
    latitude: 5.36,
    longitude: -4.0,
    destinationAddress: null,
    loadDetails: null,
  });

  // Live candidates by radius: A and B within 5km, C only once it widens.
  const liveByRadius = (radius: number) =>
    radius <= 5_000
      ? [
          { craftsmanId: 'A', distanceMeters: 1_200 },
          { craftsmanId: 'B', distanceMeters: 3_000 },
        ]
      : [
          { craftsmanId: 'A', distanceMeters: 1_200 },
          { craftsmanId: 'B', distanceMeters: 3_000 },
          { craftsmanId: 'C', distanceMeters: 8_000 },
        ];

  const emitted = (event: string, room?: string) =>
    emits.filter((e) => e.event === event && (!room || e.room === room));

  beforeEach(() => {
    jest.useFakeTimers();
    emits = [];
    matchingService = {
      updateSearchRadius: jest.fn().mockResolvedValue(undefined),
      findNearestByLastKnownLocation: jest.fn().mockResolvedValue([]),
      tryAssign: jest.fn().mockResolvedValue(true),
      expireRequest: jest.fn().mockResolvedValue(true),
    };
    presenceService = {
      findNearest: jest.fn((_c, _lon, _lat, radius: number) =>
        Promise.resolve(liveByRadius(radius)),
      ),
    };
    notificationsService = {
      sendToUser: jest.fn().mockResolvedValue(undefined),
      cancelRing: jest.fn().mockResolvedValue(undefined),
    };
    gateway = new MatchingGateway(
      matchingService as never,
      presenceService as never,
      {} as never,
      notificationsService as never,
      {
        getBlockedCounterpartIds: jest.fn().mockResolvedValue(new Set()),
      } as never,
      {
        findOne: jest
          .fn()
          .mockResolvedValue({ fullName: 'Kofi', phone: '+225' }),
      } as never,
    );
    gateway.server = {
      to: (room: string) => ({
        emit: (event: string, payload: Record<string, unknown>) =>
          emits.push({ room, event, payload }),
      }),
    } as never;
  });

  afterEach(() => jest.useRealTimers());

  const accept = (craftsmanId: string) =>
    gateway.handleAccept(
      { data: { user: { id: craftsmanId, role: 'craftsman' } } } as never,
      { requestId: 'req-1' },
    );

  it('keeps every offer open for the whole 75s window, widening to 10km at 35s, then expires', async () => {
    const loop = gateway.runMatchingLoop(request());
    await jest.advanceTimersByTimeAsync(0);

    // Step 1: within 5km, each told they have the full window.
    expect(matchingService.updateSearchRadius).toHaveBeenLastCalledWith(
      'req-1',
      5_000,
    );
    expect(emitted('request:new').map((e) => e.room)).toEqual([
      'craftsman:A',
      'craftsman:B',
    ]);
    expect(emitted('request:new')[0].payload.respondWithinSeconds).toBe(75);

    await jest.advanceTimersByTimeAsync(35_000);
    // Step 2: widened to 10km, only the newcomer is offered (40s left), and
    // nobody's offer was withdrawn.
    expect(matchingService.updateSearchRadius).toHaveBeenLastCalledWith(
      'req-1',
      10_000,
    );
    expect(emitted('request:new', 'craftsman:C')).toHaveLength(1);
    expect(
      emitted('request:new', 'craftsman:C')[0].payload.respondWithinSeconds,
    ).toBe(40);
    expect(emitted('request:new')).toHaveLength(3);
    expect(emitted('request:unavailable')).toHaveLength(0);

    await jest.advanceTimersByTimeAsync(39_000);
    expect(emitted('request:unavailable')).toHaveLength(0);
    expect(matchingService.expireRequest).not.toHaveBeenCalled();

    await jest.advanceTimersByTimeAsync(1_000);
    await loop;
    expect(
      emitted('request:unavailable')
        .map((e) => e.room)
        .sort(),
    ).toEqual(['craftsman:A', 'craftsman:B', 'craftsman:C']);
    expect(matchingService.expireRequest).toHaveBeenCalledWith('req-1');
    expect(
      emitted('request:no_craftsman_available', 'client:client-1'),
    ).toHaveLength(1);
  });

  it('lets a first-step craftsman accept late in the window (60s)', async () => {
    const loop = gateway.runMatchingLoop(request());
    await jest.advanceTimersByTimeAsync(60_000);
    accept('A');
    await loop;

    expect(matchingService.tryAssign).toHaveBeenCalledWith('req-1', 'A');
    expect(emitted('request:assigned', 'client:client-1')).toHaveLength(1);
    expect(
      emitted('request:unavailable')
        .map((e) => e.room)
        .sort(),
    ).toEqual(['craftsman:B', 'craftsman:C']);
    expect(matchingService.expireRequest).not.toHaveBeenCalled();
  });

  it('stops dispatching and withdraws every offer when the client cancels', async () => {
    const loop = gateway.runMatchingLoop(request());
    await jest.advanceTimersByTimeAsync(10_000);
    gateway.abortMatchingLoop('req-1');
    await loop;

    expect(matchingService.updateSearchRadius).toHaveBeenCalledTimes(1);
    expect(
      emitted('request:unavailable')
        .map((e) => e.room)
        .sort(),
    ).toEqual(['craftsman:A', 'craftsman:B']);
    expect(matchingService.expireRequest).not.toHaveBeenCalled();
    expect(matchingService.tryAssign).not.toHaveBeenCalled();
  });

  it('sends wake-up pushes capped to the step radius for regular trades, never for taxi', async () => {
    matchingService.findNearestByLastKnownLocation.mockResolvedValueOnce([
      { craftsmanId: 'S', distanceMeters: 4_000 },
    ]);
    const loop = gateway.runMatchingLoop(request());
    await jest.advanceTimersByTimeAsync(0);
    expect(matchingService.findNearestByLastKnownLocation).toHaveBeenCalledWith(
      ServiceCategory.ELECTRICIAN,
      -4.0,
      5.36,
      expect.arrayContaining(['A', 'B']),
      5,
      5_000,
    );
    expect(
      notificationsService.sendToUser.mock.calls.some(
        ([id, push]: [string, { body: string }]) =>
          id === 'S' && /dans la minute/.test(push.body),
      ),
    ).toBe(true);
    await jest.advanceTimersByTimeAsync(75_000);
    await loop;
    // The woken-up craftsman is withdrawn like everyone else.
    expect(emitted('request:unavailable', 'craftsman:S')).toHaveLength(1);
    // Offers ring until the window closes, and the ringing is stopped
    // for everyone once the search ends.
    const offerPushes = notificationsService.sendToUser.mock.calls.filter(
      (call: unknown[]) =>
        (call[2] as { event: string }).event === 'request:new',
    );
    expect(offerPushes.length).toBeGreaterThan(0);
    for (const call of offerPushes as unknown[][]) {
      expect((call[3] as { ringUntil?: Date }).ringUntil).toBeInstanceOf(Date);
    }
    expect(notificationsService.cancelRing).toHaveBeenCalledWith(
      expect.arrayContaining(['A', 'B', 'S']),
      expect.any(String),
    );

    matchingService.findNearestByLastKnownLocation.mockClear();
    const taxi = gateway.runMatchingLoop(request(ServiceCategory.TAXI));
    await jest.advanceTimersByTimeAsync(75_000);
    await taxi;
    expect(
      matchingService.findNearestByLastKnownLocation,
    ).not.toHaveBeenCalled();
    const taxiRadii = matchingService.updateSearchRadius.mock.calls
      .slice(-5)
      .map(([, radius]) => radius as number);
    expect(Math.max(...taxiRadii)).toBe(4_000);
  });
});
