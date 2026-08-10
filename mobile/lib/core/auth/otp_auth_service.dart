import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_tier.dart';
import '../models/user_role.dart';
import '../network/api_client.dart';

// Replaces the old Firebase-SDK-backed PhoneVerificationService: WhatsApp
// OTP is plain HTTP (POST /auth/send-otp, POST /auth/verify-otp — see
// backend/src/auth/otp.controller.ts), so there's no platform-specific SDK,
// no auto-verification, and no dev-bypass path needed — every platform goes
// through the same real flow.

sealed class VerifyOtpOutcome {}

// The phone already had an account — verify-otp logged the caller straight
// in, same as a successful POST /users/register would.
class ExistingUserSession extends VerifyOtpOutcome {
  ExistingUserSession({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.fullName,
    required this.subscriptionTier,
  });

  final String accessToken;
  final String refreshToken;
  final UserRole role;
  final String? fullName;
  final SubscriptionTier? subscriptionTier;
}

// No account exists yet for this phone — registrationToken is proof this
// phone was verified, to be sent along with POST /users/register.
class NewUserVerified extends VerifyOtpOutcome {
  NewUserVerified({required this.registrationToken});

  final String registrationToken;
}

class OtpAuthService {
  OtpAuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> sendOtp(String phone) async {
    await _apiClient.post('/auth/send-otp', {'phone': phone});
  }

  Future<VerifyOtpOutcome> verifyOtp(String phone, String code) async {
    final response = await _apiClient.post('/auth/verify-otp', {
      'phone': phone,
      'code': code,
    });

    if (response['status'] == 'existing') {
      final user = response['user'] as Map<String, dynamic>;
      return ExistingUserSession(
        accessToken: response['accessToken'] as String,
        refreshToken: response['refreshToken'] as String,
        role: switch (user['role'] as String) {
          'craftsman' => UserRole.craftsman,
          _ => UserRole.client,
        },
        fullName: user['fullName'] as String?,
        subscriptionTier: switch (user['subscriptionTier'] as String?) {
          'bronze' => SubscriptionTier.bronze,
          'silver' => SubscriptionTier.silver,
          'gold' => SubscriptionTier.gold,
          'free' => SubscriptionTier.free,
          _ => null,
        },
      );
    }

    return NewUserVerified(
      registrationToken: response['registrationToken'] as String,
    );
  }
}

final otpAuthServiceProvider = Provider<OtpAuthService>(
  (ref) => OtpAuthService(ref.watch(apiClientProvider)),
);
