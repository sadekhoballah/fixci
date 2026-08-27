import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_tier.dart';
import '../models/user_role.dart';
import '../network/api_client.dart';

// Phone OTP via Twilio Verify — plain HTTP against POST /auth/otp/start and
// POST /auth/otp/check (see backend/src/auth/otp.controller.ts). No
// platform SDK, no auto-verification: every platform goes through the same
// real flow. Replaces the old Firebase/WhatsApp-Cloud-API otp_auth_service.

sealed class OtpCheckOutcome {}

// The phone already had an account — /auth/otp/check logged the caller
// straight in, exactly like a successful POST /users/register would.
class ExistingUserSession extends OtpCheckOutcome {
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

// No account exists yet for this phone — registrationToken is short-lived
// proof the number was verified, to be sent along with POST /users/register.
class NewUserVerified extends OtpCheckOutcome {
  NewUserVerified({required this.registrationToken});

  final String registrationToken;
}

class VerifyService {
  VerifyService(this._apiClient);

  final ApiClient _apiClient;

  // channel is 'whatsapp' (the default/primary) or 'sms' (the explicit
  // fallback the user taps on the OTP screen). Returns the channel the
  // backend actually used — it can downgrade WhatsApp to SMS when
  // TWILIO_VERIFY_WHATSAPP_ENABLED is off.
  Future<String> startOtp(String phone, {required String channel}) async {
    final response = await _apiClient.post('/auth/otp/start', {
      'phone': phone,
      'channel': channel,
    });
    return response['channel'] as String? ?? channel;
  }

  Future<OtpCheckOutcome> checkOtp(String phone, String code) async {
    final response = await _apiClient.post('/auth/otp/check', {
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

final verifyServiceProvider = Provider<VerifyService>(
  (ref) => VerifyService(ref.watch(apiClientProvider)),
);
