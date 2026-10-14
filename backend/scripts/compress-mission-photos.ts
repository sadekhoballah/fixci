// One-off backfill: re-encodes every existing mission photo in place with the
// same rules as new uploads (see src/uploads/mission-photo-compress.ts).
// Filenames never change, so photo_storage_keys in the DB stay valid.
// Back the directory up first. Usage:
//   npx ts-node scripts/compress-mission-photos.ts [dir]
import { readdirSync, statSync } from 'fs';
import { join } from 'path';
import { compressMissionPhotoInPlace } from '../src/uploads/mission-photo-compress';
import { MISSION_PHOTOS_DIR } from '../src/uploads/uploads.constants';

async function main() {
  const dir = process.argv[2] ?? MISSION_PHOTOS_DIR;
  let before = 0;
  let after = 0;
  let changed = 0;
  let failed = 0;
  for (const name of readdirSync(dir).sort()) {
    const path = join(dir, name);
    if (!statSync(path).isFile() || name.endsWith('.tmp')) continue;
    const size = statSync(path).size;
    before += size;
    try {
      const newSize = await compressMissionPhotoInPlace(path);
      if (newSize != null) {
        changed++;
        console.log(`${name}  ${(size / 1024).toFixed(0)}KB -> ${(newSize / 1024).toFixed(0)}KB`);
      }
      after += newSize ?? size;
    } catch (error) {
      failed++;
      after += size;
      console.error(`FAILED ${name}: ${String(error)}`);
    }
  }
  console.log(
    `\n${dir}\ncompressed=${changed} failed=${failed} ` +
      `before=${(before / 1048576).toFixed(2)}MB after=${(after / 1048576).toFixed(2)}MB`,
  );
}

void main();
