import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  ApiConfig._();

  // Android emulators can't reach the host machine via localhost — 10.0.2.2 is
  // the documented alias for the host loopback interface. iOS simulators, web,
  // and desktop builds talk to localhost directly. `dart:io`'s Platform isn't
  // available on web, so that check must come after the kIsWeb guard. Override
  // with `--dart-define=API_BASE_URL=http://<lan-ip>:3000` to test on a physical device.
  // See also: --dart-define=SENTRY_DSN=... in main.dart, same convention.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }
}
