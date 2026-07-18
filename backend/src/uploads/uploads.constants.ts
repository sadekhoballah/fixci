import { join } from 'path';

export const UPLOADS_ROOT = join(process.cwd(), 'uploads');
export const ID_CARDS_SUBDIR = 'id-cards';
export const ID_CARDS_DIR = join(UPLOADS_ROOT, ID_CARDS_SUBDIR);
export const MAX_ID_CARD_SIZE_BYTES = 5 * 1024 * 1024;
export const ALLOWED_ID_CARD_MIME_TYPES = ['image/jpeg', 'image/png'];

// Kept in sync with mobile/lib/core/media/image_validation.dart — this is
// the authoritative check; the client-side one just avoids a wasted upload.
export const MIN_ID_CARD_DIMENSION = 300;
export const MAX_ID_CARD_ASPECT_RATIO = 3.0;
