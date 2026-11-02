import { resolveAppVersion } from './app-version.controller';

describe('resolveAppVersion', () => {
  const saved = { ...process.env };
  afterEach(() => {
    process.env = { ...saved };
  });

  it('defaults to no update prompt when nothing is configured', () => {
    delete process.env.APP_MIN_BUILD_ANDROID;
    delete process.env.APP_LATEST_BUILD_ANDROID;
    delete process.env.APP_STORE_URL_ANDROID;
    expect(resolveAppVersion('android')).toEqual({
      minBuild: 0,
      latestBuild: 0,
      storeUrl:
        'https://play.google.com/store/apps/details?id=com.fixci.mobile',
    });
  });

  it('reads per-platform builds and never reports latest below min', () => {
    process.env.APP_MIN_BUILD_IOS = '18';
    process.env.APP_LATEST_BUILD_IOS = '12';
    expect(resolveAppVersion('ios')).toMatchObject({
      minBuild: 18,
      latestBuild: 18,
      storeUrl: 'https://apps.apple.com/app/id6807899296',
    });
  });

  it('ignores garbage values', () => {
    process.env.APP_MIN_BUILD_ANDROID = 'abc';
    expect(resolveAppVersion('android').minBuild).toBe(0);
  });
});
