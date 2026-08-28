import type Redis from 'ioredis';
import {
  idDocAnalysisKey,
  saveIdDocAnalysis,
  takeIdDocAnalysis,
} from './id-doc-analysis.store';
import type { IdDocAnalysis } from './id-document-check';

function fakeRedis() {
  const store = new Map<string, string>();
  return {
    store,
    set: jest.fn((key: string, value: string) => {
      store.set(key, value);
      return Promise.resolve('OK');
    }),
    get: jest.fn((key: string) => Promise.resolve(store.get(key) ?? null)),
    del: jest.fn((key: string) => {
      store.delete(key);
      return Promise.resolve(1);
    }),
  };
}

const analysis: IdDocAnalysis = {
  verdict: 'uncertain',
  score: 4,
  reasons: ['1 mot-clé: NOM'],
  degraded: false,
};

describe('id-doc-analysis.store', () => {
  it('round-trips a verdict and stamps `at`', async () => {
    const redis = fakeRedis();
    await saveIdDocAnalysis(redis as unknown as Redis, 'id-cards/x.jpg', analysis);
    expect(redis.set).toHaveBeenCalledWith(
      idDocAnalysisKey('id-cards/x.jpg'),
      expect.any(String),
      'EX',
      expect.any(Number),
    );

    const taken = await takeIdDocAnalysis(
      redis as unknown as Redis,
      'id-cards/x.jpg',
    );
    expect(taken).toMatchObject({ verdict: 'uncertain', score: 4 });
    expect(typeof taken?.at).toBe('string');
  });

  it('deletes the key on read (consumed exactly once)', async () => {
    const redis = fakeRedis();
    await saveIdDocAnalysis(redis as unknown as Redis, 'id-cards/y.jpg', analysis);

    expect(await takeIdDocAnalysis(redis as unknown as Redis, 'id-cards/y.jpg'))
      .not.toBeNull();
    expect(redis.del).toHaveBeenCalledWith(idDocAnalysisKey('id-cards/y.jpg'));
    expect(await takeIdDocAnalysis(redis as unknown as Redis, 'id-cards/y.jpg'))
      .toBeNull();
  });

  it('returns null for a missing or empty storage key without hitting redis', async () => {
    const redis = fakeRedis();
    expect(await takeIdDocAnalysis(redis as unknown as Redis, null)).toBeNull();
    expect(await takeIdDocAnalysis(redis as unknown as Redis, undefined)).toBeNull();
    expect(redis.get).not.toHaveBeenCalled();
  });

  it('returns null when the stored JSON is corrupt', async () => {
    const redis = fakeRedis();
    redis.store.set(idDocAnalysisKey('id-cards/z.jpg'), '{not json');
    expect(
      await takeIdDocAnalysis(redis as unknown as Redis, 'id-cards/z.jpg'),
    ).toBeNull();
  });
});
