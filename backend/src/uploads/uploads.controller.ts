import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { randomUUID } from 'crypto';
import { existsSync, mkdirSync, readFileSync, unlinkSync } from 'fs';
import { extname } from 'path';
import { imageSize } from 'image-size';
import {
  ALLOWED_ID_CARD_MIME_TYPES,
  ID_CARDS_DIR,
  ID_CARDS_SUBDIR,
  MAX_ID_CARD_ASPECT_RATIO,
  MAX_ID_CARD_SIZE_BYTES,
  MIN_ID_CARD_DIMENSION,
} from './uploads.constants';

if (!existsSync(ID_CARDS_DIR)) {
  mkdirSync(ID_CARDS_DIR, { recursive: true });
}

const ALLOWED_IMAGE_SIZE_TYPES = new Set(['jpg', 'png']);

@Controller('uploads')
export class UploadsController {
  @Post('id-card')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: ID_CARDS_DIR,
        filename: (_req, file, callback) => {
          callback(null, `${randomUUID()}${extname(file.originalname)}`);
        },
      }),
      limits: { fileSize: MAX_ID_CARD_SIZE_BYTES },
      fileFilter: (_req, file, callback) => {
        if (!ALLOWED_ID_CARD_MIME_TYPES.includes(file.mimetype)) {
          callback(
            new BadRequestException('Only JPEG or PNG images are allowed'),
            false,
          );
          return;
        }
        callback(null, true);
      },
    }),
  )
  uploadIdCard(@UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    // The mimetype/extension filter above only checks what the client
    // *claims* the file is. Decode it for real before trusting it: this
    // catches corrupt files, disguised non-images, and implausible ID-card
    // photos (too small or too oddly-shaped to be one).
    try {
      const buffer = readFileSync(file.path);
      if (buffer.length === 0) {
        throw new BadRequestException('Uploaded file is empty');
      }

      const dimensions = imageSize(buffer);
      if (!ALLOWED_IMAGE_SIZE_TYPES.has(dimensions.type ?? '')) {
        throw new BadRequestException('Only JPEG or PNG images are allowed');
      }

      const { width, height } = dimensions;
      const shorter = Math.min(width, height);
      const longer = Math.max(width, height);
      if (shorter < MIN_ID_CARD_DIMENSION) {
        throw new BadRequestException(
          'Image resolution is too low to be readable',
        );
      }
      if (longer / shorter > MAX_ID_CARD_ASPECT_RATIO) {
        throw new BadRequestException(
          "Image proportions don't look like an ID card",
        );
      }
    } catch (error) {
      unlinkSync(file.path);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Uploaded file is not a valid image');
    }

    return { storageKey: `${ID_CARDS_SUBDIR}/${file.filename}` };
  }
}
