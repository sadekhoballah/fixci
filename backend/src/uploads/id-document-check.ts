import { Logger } from '@nestjs/common';
import { readFileSync } from 'fs';

// Replaces the old tesseract.js OCR pass (id-document-ocr.ts). Google Cloud
// Vision reads the uploaded photo once — full text + labels + faces in a
// single images:annotate call — and we score the result against the words
// that appear on every real CNI / passport / permis (in FR, EN and AR) plus
// an MRZ check. This is a coarse filter, never identity verification:
//   - 'pass'      strong signal it's a real document -> manual queue, low prio
//   - 'uncertain' ambiguous -> straight to the manual queue, never blocked
//   - 'reject'    basically no document signal at all -> upload refused with
//                 an actionable message (the caller still applies a per-IP
//                 retry safety-valve so a hard-to-OCR real card can't trap
//                 the user forever)
// Fail-open by construction: if the API key is unset or Vision errors /
// times out / is over quota, the verdict is 'uncertain' with degraded=true
// and the upload must be let through to a human.
//
// Same outbound-fetch idiom as auth/twilio-verify.service.ts (global fetch,
// Node 24) — no @google-cloud/vision dependency, no gRPC.

const VISION_ENDPOINT = 'https://vision.googleapis.com/v1/images:annotate';
const VISION_TIMEOUT_MS = 6000;

const logger = new Logger('IdDocumentCheck');

export type IdDocVerdict = 'pass' | 'uncertain' | 'reject';

export interface IdDocAnalysis {
  verdict: IdDocVerdict;
  // Informational 0-19ish score, for the admin panel later. Not used for the
  // verdict decision itself (that's the explicit bands in scoreDocument).
  score: number;
  // Human-readable breakdown of what fired, for logs and the admin panel.
  reasons: string[];
  // True when Google Vision couldn't be consulted at all — verdict is then
  // always 'uncertain' and the upload must NOT be rejected on our account.
  degraded: boolean;
}

// The persisted shape: an IdDocAnalysis plus the timestamp it was produced.
// Stashed in Redis by the (stateless) upload endpoint and copied onto the
// profile row when the account is finally created — see
// uploads/id-doc-analysis.store.ts. Also the jsonb column type on
// CraftsmanProfile / ClientProfile.
export interface StoredIdDocAnalysis extends IdDocAnalysis {
  at: string; // ISO 8601
}

// --- keyword lists (stored raw, normalised once at module load) -----------

const FRENCH_KEYWORDS_RAW = [
  'REPUBLIQUE',
  'COTE D IVOIRE',
  'IVOIRE',
  'CARTE NATIONALE',
  'CARTE D IDENTITE',
  'IDENTITE',
  'PASSEPORT',
  'PERMIS DE CONDUIRE',
  'PERMIS',
  'NOM',
  'PRENOMS',
  'PRENOM',
  'DATE DE NAISSANCE',
  'LIEU DE NAISSANCE',
  'NATIONALITE',
  'SEXE',
  'DELIVRE LE',
  'DELIVREE LE',
  'DATE D EXPIRATION',
  'EXPIRE LE',
  'SIGNATURE',
  'AUTORITE',
];

const ENGLISH_KEYWORDS_RAW = [
  'REPUBLIC',
  'PASSPORT',
  'IDENTITY CARD',
  'NATIONAL IDENTITY',
  'IDENTITY',
  'DRIVING LICENCE',
  'DRIVING LICENSE',
  'DRIVER LICENSE',
  'SURNAME',
  'GIVEN NAMES',
  'GIVEN NAME',
  'DATE OF BIRTH',
  'PLACE OF BIRTH',
  'NATIONALITY',
  'DATE OF ISSUE',
  'DATE OF EXPIRY',
  'AUTHORITY',
];

const ARABIC_KEYWORDS_RAW = [
  'الجمهورية اللبنانية', // الجمهورية اللبنانية
  'جمهورية', // جمهورية
  'بطاقة هوية', // بطاقة هوية
  'هوية', // هوية
  'جواز سفر', // جواز سفر
  'رخصة سوق', // رخصة سوق
  'رخصة قيادة', // رخصة قيادة
  'الاسم', // الاسم
  'الشهرة', // الشهرة
  'اسم الأب', // اسم الأب
  'اسم الأم', // اسم الأم
  'محل وتاريخ الولادة', // محل وتاريخ الولادة
  'تاريخ الولادة', // تاريخ الولادة
  'مكان الولادة', // مكان الولادة
  'الجنس', // الجنس
  'الجنسية', // الجنسية
  'رقم السجل', // رقم السجل
  'تاريخ الإصدار', // تاريخ الإصدار
];

// Vision LABEL_DETECTION descriptions. "Strong" ones alone are enough for a
// 'pass'; "weak" ones only nudge the score and keep an otherwise-empty image
// out of the 'reject' band.
const STRONG_DOC_LABELS = new Set([
  'identity document',
  'passport',
  'driving licence',
  'driving license',
  "driver's license",
  'id card',
  'identity card',
  'personal identification',
]);
const WEAK_DOC_LABELS = new Set([
  'document',
  'official document',
  'paper',
  'paper product',
  'text',
  'font',
]);

// Below this many recognised characters (and with nothing else pointing at a
// document) the image is treated as "no document at all" -> reject band.
const MIN_TEXT_CHARS = 8;
const KEYWORD_HITS_FOR_PASS = 2;

// --- normalisation ------------------------------------------------------

// One normalised haystack: strip Latin + Arabic combining marks, fold
// accented Latin to ASCII, unify Arabic alef/ya/ta-marbuta, drop everything
// that isn't a letter/digit (Latin or Arabic) to a single space, uppercase,
// and pad with spaces so callers can test for whole words with
// `includes(' ' + word + ' ')`.
export function normalize(input: string): string {
  const folded = input
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '') // Latin combining marks
    .replace(/[ؐ-ًؚ-ٰٟ]/g, '') // Arabic marks
    .replace(/ـ/g, '') // Arabic tatweel
    .replace(/[أإآ]/g, 'ا') // alef variants -> ا
    .replace(/ى/g, 'ي') // alef maqsura -> ي
    .replace(/ة/g, 'ه'); // ta marbuta -> ه
  const cleaned = folded
    .toUpperCase()
    .replace(/[^A-Z0-9؀-ۿ]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
  return ` ${cleaned} `;
}

const FRENCH_KEYWORDS = FRENCH_KEYWORDS_RAW.map((k) => normalize(k).trim());
const ENGLISH_KEYWORDS = ENGLISH_KEYWORDS_RAW.map((k) => normalize(k).trim());
const ARABIC_KEYWORDS = ARABIC_KEYWORDS_RAW.map((k) => normalize(k).trim());
const ALL_KEYWORDS = [
  ...new Set([...FRENCH_KEYWORDS, ...ENGLISH_KEYWORDS, ...ARABIC_KEYWORDS]),
].filter(Boolean);

// --- MRZ --------------------------------------------------------------

// A TD1/TD2/TD3 machine-readable zone is 2-3 lines of [A-Z0-9<] with filler
// '<'. Present -> near-decisive it's a real travel/ID document. The user
// only uploads the recto so this often won't fire; its absence means
// nothing, only its presence counts.
export function hasMrz(rawText: string): boolean {
  const lines = rawText
    .split(/\r?\n/)
    .map((l) => l.trim().toUpperCase().replace(/\s+/g, ''))
    .filter((l) => l.length >= 20);
  const mrzLike = lines.filter(
    (l) =>
      /^[A-Z0-9<]+$/.test(l) &&
      l.length >= 25 &&
      l.length <= 46 &&
      l.includes('<'),
  );
  if (mrzLike.length >= 2) return true;
  // TD3 passport line 1: P<CIV<SURNAME<<GIVEN<<<...
  return lines.some(
    (l) => /^P[A-Z<][A-Z]{3}[A-Z0-9<]+$/.test(l) && l.includes('<<'),
  );
}

// --- scoring (pure, unit-tested directly) -----------------------------

export function scoreDocument(
  rawText: string,
  labels: string[],
  faceCount: number,
): IdDocAnalysis {
  const reasons: string[] = [];
  const haystack = normalize(rawText);
  const textChars = haystack.trim().length;

  const matched = ALL_KEYWORDS.filter((kw) => haystack.includes(` ${kw} `));
  const keywordHits = matched.length;

  const lowerLabels = labels.map((l) => l.toLowerCase().trim());
  const strongLabel = lowerLabels.find((l) => STRONG_DOC_LABELS.has(l));
  const weakLabel = lowerLabels.find((l) => WEAK_DOC_LABELS.has(l));

  const mrz = hasMrz(rawText);

  let score = 0;
  if (mrz) {
    score += 5;
    reasons.push('MRZ detectee');
  }
  if (keywordHits > 0) {
    score += Math.min(keywordHits, 3) * 3;
    reasons.push(
      `${keywordHits} mot(s)-cle(s): ${matched.slice(0, 6).join(', ')}`,
    );
  }
  if (strongLabel) {
    score += 3;
    reasons.push(`label Vision: ${strongLabel}`);
  } else if (weakLabel) {
    score += 1;
    reasons.push(`label Vision faible: ${weakLabel}`);
  }
  if (faceCount > 0 && textChars >= MIN_TEXT_CHARS) {
    score += 2;
    reasons.push('visage + texte presents');
  }

  let verdict: IdDocVerdict;
  if (mrz || keywordHits >= KEYWORD_HITS_FOR_PASS || strongLabel) {
    verdict = 'pass';
  } else if (
    textChars < MIN_TEXT_CHARS &&
    keywordHits === 0 &&
    !strongLabel &&
    !weakLabel
  ) {
    verdict = 'reject';
    reasons.push('aucun texte ni indice de document');
  } else {
    verdict = 'uncertain';
    if (reasons.length === 0) reasons.push('signaux faibles / ambigus');
  }

  return { verdict, score, reasons, degraded: false };
}

function degradedResult(reason: string): IdDocAnalysis {
  return { verdict: 'uncertain', score: 0, reasons: [reason], degraded: true };
}

interface VisionAnnotateResponse {
  fullTextAnnotation?: { text?: string };
  textAnnotations?: Array<{ description?: string }>;
  labelAnnotations?: Array<{ description?: string }>;
  faceAnnotations?: unknown[];
  error?: { message?: string };
}

async function callVision(
  base64: string,
): Promise<VisionAnnotateResponse | null> {
  const apiKey = process.env.GOOGLE_VISION_API_KEY;
  if (!apiKey) return null;

  let response: Response;
  try {
    response = await fetch(`${VISION_ENDPOINT}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requests: [
          {
            image: { content: base64 },
            features: [
              { type: 'TEXT_DETECTION' },
              { type: 'LABEL_DETECTION', maxResults: 15 },
              { type: 'FACE_DETECTION', maxResults: 3 },
            ],
          },
        ],
      }),
      signal: AbortSignal.timeout(VISION_TIMEOUT_MS),
    });
  } catch (error) {
    logger.error(
      'Google Vision request failed (network/timeout)',
      error instanceof Error ? error.stack : String(error),
    );
    return null;
  }

  const json = (await response.json().catch(() => null)) as {
    responses?: VisionAnnotateResponse[];
    error?: { message?: string };
  } | null;

  if (!response.ok || !json) {
    logger.error(
      `Google Vision rejected the request: ${response.status} ${JSON.stringify(
        json?.error ?? {},
      )}`,
    );
    return null;
  }
  const first = json.responses?.[0];
  if (!first || first.error) {
    logger.error(
      `Google Vision per-image error: ${JSON.stringify(first?.error ?? {})}`,
    );
    return null;
  }
  return first;
}

export async function analyzeIdDocument(
  filePath: string,
): Promise<IdDocAnalysis> {
  let base64: string;
  try {
    base64 = readFileSync(filePath).toString('base64');
  } catch {
    return degradedResult('Fichier illisible pour l analyse');
  }

  const resp = await callVision(base64);
  if (!resp) {
    return degradedResult(
      'Analyse Google Vision indisponible - revue manuelle requise',
    );
  }

  const rawText =
    resp.fullTextAnnotation?.text ??
    resp.textAnnotations?.[0]?.description ??
    '';
  const labels = (resp.labelAnnotations ?? [])
    .map((l) => l.description ?? '')
    .filter(Boolean);
  const faceCount = (resp.faceAnnotations ?? []).length;

  return scoreDocument(rawText, labels, faceCount);
}
