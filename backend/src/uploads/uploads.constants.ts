import { join } from 'path';

export const UPLOADS_ROOT = join(process.cwd(), 'uploads');
export const ID_CARDS_SUBDIR = 'id-cards';
export const ID_CARDS_DIR = join(UPLOADS_ROOT, ID_CARDS_SUBDIR);
export const MAX_ID_CARD_SIZE_BYTES = 5 * 1024 * 1024;
export const ALLOWED_ID_CARD_MIME_TYPES = ['image/jpeg', 'image/png'];

// Driver's license photo — taxi/camion craftsmen only (see
// CraftsmanProfile.licenseStorageKey). Deliberately reuses the same size
// limit, mime allowlist, dimension/aspect-ratio, and OCR-text-density
// thresholds as the ID card below: it's the same kind of photographed
// government document, just a different upload/storage location.
export const LICENSES_SUBDIR = 'licenses';
export const LICENSES_DIR = join(UPLOADS_ROOT, LICENSES_SUBDIR);

// Kept in sync with mobile/lib/core/media/image_validation.dart — this is
// the authoritative check; the client-side one just avoids a wasted upload.
export const MIN_ID_CARD_DIMENSION = 300;
export const MAX_ID_CARD_ASPECT_RATIO = 3.0;

// The content check (id-document-check.ts, Google Vision) only ever *rejects*
// an upload when it sees no document signal at all. A real but hard-to-OCR
// card (glare, angle, low light) could hit that by accident, so we don't
// trap the user: after this many rejected attempts from the same client the
// next upload is let through to manual review instead. Counter is per-IP in
// Redis with this TTL.
export const ID_DOC_REJECT_RETRY_LIMIT = 3;
export const ID_DOC_REJECT_RETRY_TTL_SECONDS = 3600;

// Shown to the user when the content check rejects the photo — actionable on
// purpose (this is the whole point of rejecting synchronously rather than
// letting a junk image into the manual queue).
export const ID_DOC_REJECT_MESSAGE =
  "La photo ne ressemble pas à une pièce d'identité lisible (CNI, passeport " +
  'ou permis). Prenez-la en pleine lumière, à plat, sans reflet, avec toute ' +
  'la pièce dans le cadre, puis réessayez.';

// Mission/Freelance board photos (e.g. "what needs fixing") — reuses the
// same size limit and mime allowlist as the ID card/license above, but goes
// through a distinct storage subdir and deliberately skips the OCR
// text-density check in UploadsController: that check exists to reject
// non-document photos, and a repair/job photo is the exact opposite case.
export const MISSION_PHOTOS_SUBDIR = 'mission-photos';
export const MISSION_PHOTOS_DIR = join(UPLOADS_ROOT, MISSION_PHOTOS_SUBDIR);
export const MAX_MISSION_PHOTO_SIZE_BYTES = MAX_ID_CARD_SIZE_BYTES;
export const ALLOWED_MISSION_PHOTO_MIME_TYPES = ALLOWED_ID_CARD_MIME_TYPES;
