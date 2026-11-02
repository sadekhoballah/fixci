import { NotFoundException } from '@nestjs/common';
import { FallbackContactsService } from './fallback-contacts.service';
import { ServiceCategory } from '../database/enums/service-category.enum';

describe('FallbackContactsService', () => {
  let service: FallbackContactsService;
  let query: jest.Mock;
  let sendToUser: jest.Mock;
  let previousContact: boolean;
  let expiredRequestFound: boolean;

  const craftsmanRow = {
    user_id: 'A',
    full_name: 'Kofi Yao',
    phone: '+2250700000001',
    distance_meters: '1234.6',
    average_rating: '4.50',
    ratings_count: 12,
    completed_jobs_count: 9,
  };

  beforeEach(() => {
    previousContact = false;
    expiredRequestFound = true;
    query = jest.fn((sql: string) => {
      if (sql.includes(`sr."status" = 'expired'`)) {
        return Promise.resolve(
          expiredRequestFound
            ? [
                {
                  id: 'req-1',
                  client_id: 'client-1',
                  service_category: ServiceCategory.PLUMBER,
                  longitude: -4,
                  latitude: 5.3,
                  district_name: 'Cocody',
                },
              ]
            : [],
        );
      }
      if (sql.includes('FROM "craftsman_profiles" cp')) {
        return Promise.resolve([craftsmanRow]);
      }
      if (sql.startsWith('SELECT 1 FROM "service_request_contacts"')) {
        return Promise.resolve(previousContact ? [{}] : []);
      }
      return Promise.resolve([]);
    });
    sendToUser = jest.fn().mockResolvedValue(undefined);
    service = new FallbackContactsService(
      { query } as never,
      { onlineAmong: jest.fn().mockResolvedValue(new Set(['A'])) } as never,
      {
        getBlockedCounterpartIds: jest.fn().mockResolvedValue(new Set(['X'])),
      } as never,
      { sendToUser } as never,
    );
  });

  it('lists the nearest eligible craftsmen with rating, jobs, online badge and phone', async () => {
    const list = await service.getFallbackList('req-1', 'client-1');

    expect(list).toEqual({
      requestId: 'req-1',
      serviceCategory: ServiceCategory.PLUMBER,
      clientDistrictName: 'Cocody',
      craftsmen: [
        {
          id: 'A',
          fullName: 'Kofi Yao',
          phone: '+2250700000001',
          distanceMeters: 1235,
          averageRating: 4.5,
          ratingsCount: 12,
          completedJobsCount: 9,
          isOnline: true,
        },
      ],
    });
    const [, params] = query.mock.calls.find(([sql]) =>
      (sql as string).includes('FROM "craftsman_profiles" cp'),
    ) as [string, unknown[]];
    // Blocked counterparts excluded, 20km cap, 3 results, no license gate
    // for a plumber.
    expect(params).toEqual([
      -4,
      5.3,
      ServiceCategory.PLUMBER,
      ['X'],
      20_000,
      false,
      3,
    ]);
  });

  it('refuses a request that is not this client’s, not expired, or too old', async () => {
    expiredRequestFound = false;
    await expect(service.getFallbackList('req-1', 'client-2')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('records a contact and pushes the craftsman only the first time', async () => {
    await service.recordContact('req-1', 'client-1', 'A', 'whatsapp');
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO "service_request_contacts"'),
      ['req-1', 'client-1', 'A', 'whatsapp'],
    );
    expect(sendToUser).toHaveBeenCalledTimes(1);
    expect(sendToUser).toHaveBeenCalledWith(
      'A',
      expect.anything(),
      expect.anything(),
    );

    previousContact = true;
    await service.recordContact('req-1', 'client-1', 'A', 'call');
    expect(sendToUser).toHaveBeenCalledTimes(1);
  });

  it('refuses to record (or push) a craftsman who is not on the list', async () => {
    await expect(
      service.recordContact('req-1', 'client-1', 'Z', 'call'),
    ).rejects.toThrow(NotFoundException);
    expect(sendToUser).not.toHaveBeenCalled();
    expect(query).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO'),
      expect.anything(),
    );
  });
});
