import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// firebase_auth has no official Linux/Windows desktop implementation (unlike
// image_picker, there's no drop-in fallback package for phone auth either —
// see core/auth/phone_verification_service.dart for how that gap is handled).
bool get isFirebaseSupportedPlatform =>
    kIsWeb || Platform.isAndroid || Platform.isIOS;
