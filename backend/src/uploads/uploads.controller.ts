import {
  BadRequestException,
  Controller,
  Get,
  Inject,
  Logger,
  NotFoundException,
  Param,
  Post,
  Req,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { InjectRepository } from '@nestjs/typeorm';
import { Throttle } from '@nestjs/throttler';
import { Repository } from 'typeorm';
import type { Request, Response } from 'express';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { diskStorage } from 'multer';
import { randomUUID } from 'crypto';
import { existsSync, mkdirSync, readFileSync, unlinkSync } from 'fs';
import { extname, join } from 'path';
import { imageSize } from 'image-size';
import {
  ALLOWED_ID_CARD_MIME_TYPES,
  ALLOWED_MISSION_PHOTO_MIME_TYPES,
  ID_CARDS_DIR,
  ID_CARDS_SUBDIR,
  ID_DOC_REJECT_MESSAGE,
  ID_DOC_REJECT_RETRY_LIMIT,
  ID_DOC_REJECT_RETRY_TTL_SECONDS,
  LICENSES_DIR,
  LICENSES_SUBDIR,
  MAX_ID_CARD_ASPECT_RATIO,
  MAX_ID_CARD_SIZE_BYTES,
  MAX_MISSION_PHOTO_SIZE_BYTES,
  MIN_ID_CARD_DIMENSION,
  MISSION_PHOTOS_DIR,
  MISSION_PHOTOS_SUBDIR,
} from './uploads.constants';
import { analyzeIdDocument } from './id-document-check';
import type { IdDocAnalysis } from './id-document-check';
import { saveIdDocAnalysis } from './id-doc-analysis.store';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { Mission } from '../database/entities/mission.entity';
import { MissionStatus } from '../database/enums/mission-status.enum';

if (!existsSync(ID_CARDS_DIR)) {
  mkdirSync(ID_CARDS_DIR, { recursive: true });
}
if (!existsSync(LICENSES_DIR)) {
  mkdirSync(LICENSES_DIR, { recursive: true });
}
if (!existsSync(MISSION_PHOTOS_DIR)) {
  mkdirSync(MISSION_PHOTOS_DIR, { recursive: true });
}

const ALLOWED_IMAGE_SIZE_TYPES = new Set(['jpg', 'png']);

@Controller('uploads')
export class UploadsController {
  private readonly logger = new Logger(UploadsController.name);

  constructor(
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    @InjectRepository(Mission)
    private readonly missionRepository: Repository<Mission>,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
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
  async uploadIdCard(
    @Req() req: Request,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    const analysis = await this.assertLooksLikeDocumentPhoto(file.path, req);
    const storageKey = `${ID_CARDS_SUBDIR}/${file.filename}`;
    await this.stashAnalysis(storageKey, analysis);
    return { storageKey };
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
  async uploadLicense(
    @Req() req: Request,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    const analysis = await this.assertLooksLikeDocumentPhoto(file.path, req);
    const storageKey = `${LICENSES_SUBDIR}/${file.filename}`;
    await this.stashAnalysis(storageKey, analysis);
    return { storageKey };
  }

  // Mission/Freelance board photo — unlike id-card/license above, this IS
  // behind AuthGuard: posting a mission always happens post-registration, so
  // there's no pre-account gap to accommodate here. Deliberately skips
  // assertLooksLikeDocumentPhoto's OCR check (see uploads.constants.ts) —
  // only the generic decode/size/dimension sanity check applies.
  @Post('mission-photo')
  @UseGuards(AuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: MISSION_PHOTOS_DIR,
        filename: (_req, file, callback) => {
          callback(null, `${randomUUID()}${extname(file.originalname)}`);
        },
      }),
      limits: { fileSize: MAX_MISSION_PHOTO_SIZE_BYTES },
      fileFilter: (_req, file, callback) => {
        if (!ALLOWED_MISSION_PHOTO_MIME_TYPES.includes(file.mimetype)) {
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
  uploadMissionPhoto(@UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    this.assertLooksLikeGenericPhoto(file.path);
    return { storageKey: `${MISSION_PHOTOS_SUBDIR}/${file.filename}` };
  }

  // The mimetype/extension filter on each FileInterceptor above only checks
  // what the client *claims* the file is. Decode it for real before trusting
  // it: this catches corrupt files, disguised non-images, and implausible
  // document photos (too small or too oddly-shaped to be one). Shared by
  // uploadIdCard and uploadLicense — same document-photo shape either way.
  private async assertLooksLikeDocumentPhoto(
    filePath: string,
    req: Request,
  ): Promise<IdDocAnalysis> {
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
    } catch (error) {
      unlinkSync(filePath);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Uploaded file is not a valid image');
    }

    // None of the checks above look at the image's *content* — a plausibly
    // sized/shaped photo of a car or a blank wall would still pass them.
    // Google Vision (id-document-check.ts) reads the photo once and scores it
    // against the words on a real CNI/passport/permis (FR/EN/AR) + an MRZ
    // check. Only a 'reject' verdict — essentially no document signal at all —
    // blocks the upload; 'pass'/'uncertain'/degraded all go through to the
    // human review queue (idVerified stays false regardless). Fail-open: any
    // error here must not block registration.
    let analysis: IdDocAnalysis;
    try {
      analysis = await analyzeIdDocument(filePath);
    } catch (error) {
      this.logger.error(
        'ID document analysis threw unexpectedly — letting the upload through',
        error instanceof Error ? error.stack : String(error),
      );
      return {
        verdict: 'uncertain',
        score: 0,
        reasons: ['analyse: exception interne'],
        degraded: true,
      };
    }

    if (analysis.verdict !== 'reject') {
      if (analysis.degraded) {
        this.logger.warn(
          `ID document check degraded (${analysis.reasons.join('; ')}) — routing to manual review`,
        );
      }
      return analysis;
    }

    // Clear 'reject'. Refuse it with an actionable message — unless this
    // client has already been bounced enough times, in which case a real but
    // hard-to-OCR card mustn't trap them: let it through to manual review
    // (the verdict is still recorded as 'reject' for the admin, with a note
    // that the safety-valve waved it through).
    if (await this.overIdDocRejectLimit(req)) {
      this.logger.warn(
        `ID document 'reject' verdict overridden by retry safety-valve (${this.clientKey(req)}) — routing to manual review`,
      );
      return {
        ...analysis,
        reasons: [...analysis.reasons, 'laissé passer (soupape anti-blocage)'],
      };
    }
    unlinkSync(filePath);
    throw new BadRequestException(ID_DOC_REJECT_MESSAGE);
  }

  // Best-effort hand-off of the Vision verdict to the (later, separate)
  // registration request — see uploads/id-doc-analysis.store.ts. Never fatal:
  // a Redis hiccup here just means the profile stores no auto-check.
  private async stashAnalysis(
    storageKey: string,
    analysis: IdDocAnalysis,
  ): Promise<void> {
    try {
      await saveIdDocAnalysis(this.redis, storageKey, analysis);
    } catch (error) {
      this.logger.warn(
        `Could not stash ID document analysis for ${storageKey}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }

  // Best-effort client identity for the reject-retry counter: the first hop
  // in X-Forwarded-For (set by the cloudflared/Apache front) if present, else
  // Express's req.ip. Not a security control — worst case it degrades to a
  // shared counter that only ever lets more users through.
  private clientKey(req: Request): string {
    const header = req.headers['x-forwarded-for'];
    const raw = Array.isArray(header) ? header[0] : header;
    const forwarded = raw?.split(',')[0]?.trim();
    return forwarded || req.ip || 'unknown';
  }

  private async overIdDocRejectLimit(req: Request): Promise<boolean> {
    const key = `iddoc:rejects:${this.clientKey(req)}`;
    const count = await this.redis.incr(key);
    if (count === 1) {
      await this.redis.expire(key, ID_DOC_REJECT_RETRY_TTL_SECONDS);
    }
    return count > ID_DOC_REJECT_RETRY_LIMIT;
  }

  // Mission photo counterpart to assertLooksLikeDocumentPhoto above — same
  // decode/empty-file/dimension floor, but deliberately no aspect-ratio cap
  // and no OCR pass: a repair/job photo can be any shape, and is the exact
  // opposite of a text-dense document.
  private assertLooksLikeGenericPhoto(filePath: string): void {
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
      if (Math.min(width, height) < MIN_ID_CARD_DIMENSION) {
        throw new BadRequestException(
          'Image resolution is too low to be readable',
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

  // Different ownership model from id-card/license (which are always
  // private): a mission photo becomes visible to everyone once its mission
  // is published, since that's the whole point of the board. Before/without
  // publication, only the poster can preview their own pending/rejected
  // mission's photos.
  @Get('mission-photo/:filename')
  @UseGuards(AuthGuard)
  async getMissionPhoto(
    @CurrentUser() user: AuthenticatedUser,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    if (filename.includes('/') || filename.includes('..')) {
      throw new NotFoundException('No photo found');
    }
    const storageKey = `${MISSION_PHOTOS_SUBDIR}/${filename}`;

    const mission = await this.missionRepository
      .createQueryBuilder('m')
      .where(':key = ANY(m.photoStorageKeys)', { key: storageKey })
      .getOne();

    if (!mission) {
      throw new NotFoundException('No photo found');
    }
    const visible =
      mission.status === MissionStatus.APPROVED_PUBLISHED ||
      mission.status === MissionStatus.IN_PROGRESS ||
      mission.status === MissionStatus.COMPLETED ||
      mission.posterId === user.id;
    if (!visible) {
      throw new NotFoundException('No photo found');
    }

    res.sendFile(join(MISSION_PHOTOS_DIR, filename));
  }
}
