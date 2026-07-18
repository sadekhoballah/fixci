import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/firebase_support.dart';
import 'dev_bypass_phone_verification_service.dart';
import 'firebase_phone_verification_service.dart';
import 'phone_verification_service.dart';

final phoneVerificationServiceProvider = Provider<PhoneVerificationService>((
  ref,
) {
  if (isFirebaseSupportedPlatform) {
    return FirebasePhoneVerificationService();
  }
  if (kDebugMode) {
    return DevBypassPhoneVerificationService();
  }
  throw UnsupportedError(
    'Phone verification is unavailable on this platform in release mode.',
  );
});
