import { mkdtempSync, writeFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import {
  analyzeIdDocument,
  hasMrz,
  normalize,
  scoreDocument,
} from './id-document-check';

describe('normalize', () => {
  it('folds Latin accents and drops punctuation, upper-cases, pads', () => {
    expect(normalize("République de Côte d'Ivoire — PRÉNOMS")).toBe(
      ' REPUBLIQUE DE COTE D IVOIRE PRENOMS ',
    );
  });

  it('unifies Arabic alef / ya / ta-marbuta and strips marks', () => {
    expect(normalize('بطاقة هُوية الجنسية')).toBe(' بطاقه هويه الجنسيه ');
  });
});

describe('hasMrz', () => {
  it('detects a TD3 passport MRZ pair', () => {
    const text =
      'P<CIVDUPONT<<JEAN<<<<<<<<<<<<<<<<<<<<<<<<<<<\n' +
      'L898902C36CIV7408122M1204159ZE184226B<<<<<10';
    expect(hasMrz(text)).toBe(true);
  });

  it('is false for ordinary card text', () => {
    expect(hasMrz('REPUBLIQUE DE COTE D IVOIRE\nNOM DUPONT')).toBe(false);
  });
});

describe('scoreDocument', () => {
  it('passes on two or more field keywords', () => {
    const r = scoreDocument(
      'REPUBLIQUE DE COTE D IVOIRE\nNOM: X\nPRENOMS: Y\nNATIONALITE: IVOIRIENNE',
      [],
      1,
    );
    expect(r.verdict).toBe('pass');
    expect(r.degraded).toBe(false);
  });

  it('passes on a strong Vision label even with no readable text', () => {
    expect(scoreDocument('....', ['Passport'], 1).verdict).toBe('pass');
  });

  it('passes on Arabic field keywords', () => {
    const r = scoreDocument('بطاقة هوية\nالجنسية لبنانية\nالشهرة', [], 1);
    expect(r.verdict).toBe('pass');
  });

  it('rejects a blank / textless image with no document label', () => {
    expect(scoreDocument('   ', [], 0).verdict).toBe('reject');
    expect(scoreDocument('', ['Car', 'Vehicle', 'Wheel'], 0).verdict).toBe(
      'reject',
    );
  });

  it('rejects a random scene with only incidental text (no ID signal)', () => {
    // Text present, but no field keyword, no document label, no face —
    // incidental text alone must not be enough to escape the reject band.
    expect(
      scoreDocument('OPEN 24 HOURS PARKING GARAGE ENTRANCE', [], 0).verdict,
    ).toBe('reject');
    expect(
      scoreDocument('some caption', ['Snapshot', 'Selfie'], 0).verdict,
    ).toBe('reject');
  });

  it('is uncertain (not rejected) on a single weak keyword', () => {
    expect(scoreDocument('PRENOMS scribbled here', [], 0).verdict).toBe(
      'uncertain',
    );
  });

  it('is uncertain when only a weak "document" label is present', () => {
    expect(scoreDocument('some text', ['Document'], 0).verdict).toBe(
      'uncertain',
    );
  });

  it('is uncertain (not rejected) on a portrait with some text', () => {
    // A photographed ID whose OCR is too poor for keywords still has a face
    // and text — must reach a human, not be blocked.
    expect(scoreDocument('blurry unreadable text here', [], 1).verdict).toBe(
      'uncertain',
    );
  });
});

describe('analyzeIdDocument', () => {
  let dir: string;
  let file: string;
  const realFetch = global.fetch;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'iddoc-'));
    file = join(dir, 'photo.jpg');
    writeFileSync(file, Buffer.from([0xff, 0xd8, 0xff, 0xd9]));
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
    global.fetch = realFetch;
    delete process.env.GOOGLE_VISION_API_KEY;
  });

  it('is degraded/uncertain when no API key is configured', async () => {
    const r = await analyzeIdDocument(file);
    expect(r).toMatchObject({ verdict: 'uncertain', degraded: true });
  });

  it('is degraded/uncertain when the Vision call throws', async () => {
    process.env.GOOGLE_VISION_API_KEY = 'k';
    global.fetch = jest.fn().mockRejectedValue(new Error('network')) as never;
    const r = await analyzeIdDocument(file);
    expect(r).toMatchObject({ verdict: 'uncertain', degraded: true });
  });

  it('is degraded/uncertain on a non-2xx Vision response', async () => {
    process.env.GOOGLE_VISION_API_KEY = 'k';
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: async () => ({ error: { message: 'denied' } }),
    }) as never;
    const r = await analyzeIdDocument(file);
    expect(r).toMatchObject({ verdict: 'uncertain', degraded: true });
  });

  it('scores the Vision payload when the call succeeds', async () => {
    process.env.GOOGLE_VISION_API_KEY = 'k';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        responses: [
          {
            fullTextAnnotation: {
              text: 'REPUBLIQUE DE COTE D IVOIRE\nNOM\nPRENOMS\nNATIONALITE',
            },
            labelAnnotations: [{ description: 'Identity document' }],
            faceAnnotations: [{}],
          },
        ],
      }),
    }) as never;
    const r = await analyzeIdDocument(file);
    expect(r.verdict).toBe('pass');
    expect(r.degraded).toBe(false);
  });

  it('rejects when Vision finds no document signal', async () => {
    process.env.GOOGLE_VISION_API_KEY = 'k';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        responses: [
          {
            labelAnnotations: [
              { description: 'Car' },
              { description: 'Vehicle' },
            ],
            faceAnnotations: [],
          },
        ],
      }),
    }) as never;
    const r = await analyzeIdDocument(file);
    expect(r.verdict).toBe('reject');
  });
});
