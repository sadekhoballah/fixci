import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_tier.dart';
import '../models/user_role.dart';
import '../network/api_client.dart';

class ExistingAccount {
  const ExistingAccount({
    required this.role,
    required this.subscriptionTier,
    required this.isAdmin,
  });

  final UserRole role;
  final SubscriptionTier? subscriptionTier;
  final bool isAdmin;
}

class UserLookupService {
  UserLookupService(this._apiClient);

  final ApiClient _apiClient;

  // Used during the "registration" flow right after OTP verification, to
  // check whether this phone already has an account before ever attempting
  // to create a new one — see OnboardingController.completeAfterVerification.
  // A 404 unambiguously means "no account yet"; any other failure (network,
  // 401, 5xx) is rethrown so the caller surfaces it instead of guessing.
  Future<ExistingAccount?> findExistingAccount() async {
    try {
      final response = await _apiClient.get('/users/lookup');
      final role = switch (response['role'] as String) {
        'craftsman' => UserRole.craftsman,
        _ => UserRole.client,
      };
      final tier = switch (response['subscriptionTier'] as String?) {
        'bronze' => SubscriptionTier.bronze,
        'silver' => SubscriptionTier.silver,
        'gold' => SubscriptionTier.gold,
        'free' => SubscriptionTier.free,
        _ => null,
      };
      return ExistingAccount(
        role: role,
        subscriptionTier: tier,
        isAdmin: response['isAdmin'] as bool? ?? false,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // Confirms a cached local session still corresponds to a real account —
  // a role saved in SharedPreferences means nothing on its own if the
  // account was deleted server-side since the last launch. The backend
  // derives the phone to look up from the caller's own auth token, so this
  // can only ever check the signed-in user's own account. Network/server
  // errors are treated as "can't confirm" (true) rather than "not
  // registered", so a dropped connection doesn't wrongly force
  // re-registration.
  Future<bool> isPhoneStillRegistered() async {
    try {
      await _apiClient.get('/users/lookup');
      return true;
    } on ApiException catch (e) {
      return e.statusCode != 404 && e.statusCode != 401;
    }
  }
}

final userLookupServiceProvider = Provider<UserLookupService>(
  (ref) => UserLookupService(ref.watch(apiClientProvider)),
);
