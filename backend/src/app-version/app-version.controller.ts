import { Controller, Get, Query } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';

export type AppPlatform = 'android' | 'ios';

export interface AppVersionInfo {
  // Builds below minBuild are blocked by a full-screen "update required"
  // screen; builds below latestBuild get a dismissible "new version" prompt.
  // Both compare against the build number after the "+" in pubspec.yaml.
  minBuild: number;
  latestBuild: number;
  storeUrl: string;
}

const DEFAULT_STORE_URLS: Record<AppPlatform, string> = {
  android: 'https://play.google.com/store/apps/details?id=com.fixci.mobile',
  ios: 'https://apps.apple.com/app/id6807899296',
};

function readBuild(name: string): number {
  const value = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isFinite(value) && value > 0 ? value : 0;
}

// Read per request (not cached at boot) so bumping APP_MIN_BUILD_* in .env
// and restarting is the only step needed to force an update.
export function resolveAppVersion(platform: AppPlatform): AppVersionInfo {
  const suffix = platform.toUpperCase();
  const minBuild = readBuild(`APP_MIN_BUILD_${suffix}`);
  const latestBuild = Math.max(
    readBuild(`APP_LATEST_BUILD_${suffix}`),
    minBuild,
  );
  return {
    minBuild,
    latestBuild,
    storeUrl:
      process.env[`APP_STORE_URL_${suffix}`]?.trim() ||
      DEFAULT_STORE_URLS[platform],
  };
}

@Controller('app')
export class AppVersionController {
  // Public and unauthenticated: it's hit on every launch and resume, before
  // any login, so it must not count against the global rate limit.
  @SkipThrottle()
  @Get('version')
  getVersion(@Query('platform') platform?: string): AppVersionInfo {
    return resolveAppVersion(platform === 'ios' ? 'ios' : 'android');
  }
}
