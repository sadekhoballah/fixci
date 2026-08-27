import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/media/id_card_picker.dart';
import '../../core/models/district.dart';
import '../../core/models/subscription_tier.dart';
import '../../core/models/user_role.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_state.dart';

class RegisteredTokens {
  const RegisteredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class OnboardingRepository {
  OnboardingRepository(this._apiClient, this._l10n);

  final ApiClient _apiClient;
  final AppLocalizations _l10n;

  Future<List<District>> getDistricts() async {
    final response = await _apiClient.get('/districts');
    return (response['items'] as List)
        .map((raw) => District.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadIdCard(PickedImage image) async {
    final response = await _apiClient.postMultipart(
      '/uploads/id-card',
      'file',
      image.bytes,
      image.filename,
      contentTypeHeader: image.mimeType,
    );
    return response['storageKey'] as String;
  }

  Future<String> uploadLicense(PickedImage image) async {
    final response = await _apiClient.postMultipart(
      '/uploads/license',
      'file',
      image.bytes,
      image.filename,
      contentTypeHeader: image.mimeType,
    );
    return response['storageKey'] as String;
  }

  Future<RegisteredTokens> registerUser(OnboardingState state) async {
    final role = state.role;
    if (role == null) {
      throw ApiException(_l10n.selectRoleBeforeContinuingMessage);
    }

    final response = await _apiClient.post('/users/register', {
      'phone': state.phone.trim(),
      'fullName': state.fullName.trim(),
      'role': role.wireValue,
      'districtId': state.district!.id,
      'idCardStorageKey': state.idCardStorageKey,
      'registrationToken': state.registrationToken,
      if (role == UserRole.craftsman && state.serviceCategory != null)
        'serviceCategory': state.serviceCategory!.wireValue,
      if (role == UserRole.craftsman)
        'experienceDetails': state.experienceDetails.trim(),
      if (role == UserRole.craftsman &&
          (state.serviceCategory?.requiresDriverLicense ?? false))
        'licenseStorageKey': state.licenseStorageKey,
    });
    return RegisteredTokens(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
    );
  }

  // Kicks off a Wave charge for the given plan and returns our reference —
  // the payment stays `pending` server-side until the Wave webhook (or, for
  // now, the stub that simulates it) resolves it. Poll [getPaymentStatus]
  // with that reference to find out when it does.
  Future<String> subscribeToTier(SubscriptionTier tier) async {
    final response = await _apiClient.post('/payments/subscribe', {
      'tier': tier.wireValue,
    });
    return response['reference'] as String;
  }

  Future<String> getPaymentStatus(String reference) async {
    final response = await _apiClient.get(
      '/payments/status?reference=${Uri.encodeQueryComponent(reference)}',
    );
    return response['status'] as String;
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(
    ref.watch(apiClientProvider),
    ref.watch(l10nProvider),
  ),
);

// Fetched once per app session — the registration screen's district
// dropdown watches this instead of a hardcoded list, since the founder can
// add new districts from the admin panel at any time.
final districtsProvider = FutureProvider<List<District>>(
  (ref) => ref.watch(onboardingRepositoryProvider).getDistricts(),
);
