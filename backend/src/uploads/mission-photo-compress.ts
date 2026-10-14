import { readFileSync, renameSync, writeFileSync } from 'fs';
import sharp from 'sharp';
import {
  MAX_COMPRESSED_MISSION_PHOTO_BYTES,
  MISSION_PHOTO_JPEG_QUALITIES,
  MISSION_PHOTO_MAX_DIMENSION,
} from './uploads.constants';

// Re-encodes a mission photo in place: EXIF-rotated, longest side capped at
// MISSION_PHOTO_MAX_DIMENSION, JPEG at the highest quality step that fits
// under MAX_COMPRESSED_MISSION_PHOTO_BYTES. The filename (and therefore the
// storage key already handed back to the client / saved on the mission) is
// never changed — a ".png" key may end up holding JPEG bytes, which is fine
// because every reader (mobile app, admin panel) decodes from the bytes via
// Image.memory rather than trusting the extension.
//
// Server-side on purpose: the shipped mobile builds upload full-resolution
// camera photos (no imageQuality/maxWidth on pickImage), and this fixes the
// board's load time without a new store release.
//
// Returns the final size, or null when the file was left untouched (already
// small enough and not oversized in pixels).
export async function compressMissionPhotoInPlace(
  filePath: string,
): Promise<number | null> {
  const original = readFileSync(filePath);
  const meta = await sharp(original).metadata();
  const longest = Math.max(meta.width ?? 0, meta.height ?? 0);
  if (
    original.length <= MAX_COMPRESSED_MISSION_PHOTO_BYTES &&
    longest <= MISSION_PHOTO_MAX_DIMENSION
  ) {
    return null;
  }

  let output: Buffer | null = null;
  for (const quality of MISSION_PHOTO_JPEG_QUALITIES) {
    output = await sharp(original)
      .rotate()
      .resize({
        width: MISSION_PHOTO_MAX_DIMENSION,
        height: MISSION_PHOTO_MAX_DIMENSION,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .flatten({ background: '#ffffff' })
      .jpeg({ quality, mozjpeg: true })
      .toBuffer();
    if (output.length <= MAX_COMPRESSED_MISSION_PHOTO_BYTES) break;
  }
  // Never make a file bigger than what we started with.
  if (!output || output.length >= original.length) {
    return null;
  }

  // Write-then-rename so a concurrent GET never sees a half-written file.
  const tmpPath = `${filePath}.tmp`;
  writeFileSync(tmpPath, output);
  renameSync(tmpPath, filePath);
  return output.length;
}
