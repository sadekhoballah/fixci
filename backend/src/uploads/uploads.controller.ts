import {
  BadRequestException,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { InjectRepository } from '@nestjs/typeorm';
import { Throttle } from '@nestjs/throttler';
import { Repository } from 'typeorm';
import type { Response } from 'express';
import { diskStorage } from 'multer';
import { randomUUID } from 'crypto';
import { existsSync, mkdirSync, readFileSync, unlinkSync } from 'fs';
import { extname, join } from 'path';
import { imageSize } from 'image-size';
import {
  ALLOWED_ID_CARD_MIME_TYPES,
  ID_CARDS_DIR,
  ID_CARDS_SUBDIR,
  LICENSES_DIR,
  LICENSES_SUBDIR,
  MAX_ID_CARD_ASPECT_RATIO,
  MAX_ID_CARD_SIZE_BYTES,
  MIN_ID_CARD_DIMENSION,
  MIN_ID_DOCUMENT_TEXT_CHARACTERS,
} from './uploads.constants';
import { extractDocumentText } from './id-document-ocr';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';

if (!existsSync(ID_CARDS_DIR)) {
  mkdirSync(ID_CARDS_DIR, { recursive: true });
}
if (!existsSync(LICENSES_DIR)) {
  mkdirSync(LICENSES_DIR, { recursive: true });
}

const ALLOWED_IMAGE_SIZE_TYPES = new Set(['jpg', 'png']);

@Controller('uploads')
export class UploadsController {
  constructor(
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
  ) {}

  // Deliberately NOT behind an auth guard: the registration screen lets a
  // user attach their ID card before POST /users/register is ever called
  // (see registration_screen.dart — the picker sits above the "S'inscrire"
  // button), so no access token exists yet at the time this is called, on
  // any platform. There is nothing to verify a caller's identity against
  // here by construction, not by oversight — don't "fix" this by adding a
  // guard back without first moving ID-card attachment later in the UI
  // flow. What actually protects this data is the authenticated,
  // ownership-checked GET below, plus the size/type/dimension validation
  // and rate limiting here.
  @Post('id-card')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
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
  async uploadIdCard(@UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    await this.assertLooksLikeDocumentPhoto(file.path);
    return { storageKey: `${ID_CARDS_SUBDIR}/${file.filename}` };
  }

  // Second KYC document, taxi/camion craftsmen only (see
  // CraftsmanProfile.licenseStorageKey) — same rationale/guards as
  // uploadIdCard above (no AuthGuard, same throttle, same photo validation),
  // just a distinct storage subdir so the two documents never collide.
  @Post('license')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: LICENSES_DIR,
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
  async uploadLicense(@UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    await this.assertLooksLikeDocumentPhoto(file.path);
    return { storageKey: `${LICENSES_SUBDIR}/${file.filename}` };
  }

  // The mimetype/extension filter on each FileInterceptor above only checks
  // what the client *claims* the file is. Decode it for real before trusting
  // it: this catches corrupt files, disguised non-images, and implausible
  // document photos (too small or too oddly-shaped to be one). Shared by
  // uploadIdCard and uploadLicense — same document-photo shape either way.
  private async assertLooksLikeDocumentPhoto(filePath: string): Promise<void> {
    try {
      const buffer = readFileSync(filePath);
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

      // None of the checks above look at the image's *content* — a plausibly
      // sized/shaped photo of a car or a blank wall would still pass them.
      // A real CNI/passport/permis is dense with printed text; a quick OCR
      // pass is enough to reject the obvious non-documents client-side
      // validation can't catch. This is a coarse filter, not identity
      // verification — idVerified/licenseVerified stay false either way,
      // for a human to review.
      const text = await extractDocumentText(filePath);
      if (text.length < MIN_ID_DOCUMENT_TEXT_CHARACTERS) {
        throw new BadRequestException(
          'Le fichier téléchargé ne ressemble pas à un document officiel (CNI/Passeport/Permis). Veuillez réessayer avec une photo claire.',
        );
      }
    } catch (error) {
      unlinkSync(filePath);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Uploaded file is not a valid image');
    }
  }

  // Replaces the previous public static-file serving of /uploads: an ID-card
  // photo is sensitive, and a UUID filename alone isn't access control.
  // Only the account that owns this exact storage key can fetch it back.
  @Get('id-card/:filename')
  @UseGuards(AuthGuard)
  async getIdCard(
    @CurrentUser() user: AuthenticatedUser,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    if (filename.includes('/') || filename.includes('..')) {
      throw new NotFoundException('No ID card found for this account');
    }
    const storageKey = `${ID_CARDS_SUBDIR}/${filename}`;

    const [craftsmanProfile, clientProfile] = await Promise.all([
      this.craftsmanProfileRepository.findOne({
        where: { userId: user.id, idCardStorageKey: storageKey },
      }),
      this.clientProfileRepository.findOne({
        where: { userId: user.id, idCardStorageKey: storageKey },
      }),
    ]);

    if (!craftsmanProfile && !clientProfile) {
      throw new NotFoundException('No ID card found for this account');
    }

    res.sendFile(join(ID_CARDS_DIR, filename));
  }

  // Owner-checked counterpart to GET /uploads/id-card/:filename, for the
  // license document. Only craftsmen ever have one, so only that repository
  // is checked (unlike the id-card version, which also checks clients).
  @Get('license/:filename')
  @UseGuards(AuthGuard)
  async getLicense(
    @CurrentUser() user: AuthenticatedUser,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    if (filename.includes('/') || filename.includes('..')) {
      throw new NotFoundException('No license found for this account');
    }
    const storageKey = `${LICENSES_SUBDIR}/${filename}`;

    const craftsmanProfile = await this.craftsmanProfileRepository.findOne({
      where: { userId: user.id, licenseStorageKey: storageKey },
    });

    if (!craftsmanProfile) {
      throw new NotFoundException('No license found for this account');
    }

    res.sendFile(join(LICENSES_DIR, filename));
  }
}
