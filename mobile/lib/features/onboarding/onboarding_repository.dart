import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/media/id_card_picker.dart';
import '../../core/models/district.dart';
import '../../core/models/subscription_tier.dart';
import '../../core/models/user_role.dart';
import 'onboarding_state.dart';

class OnboardingRepository {
  OnboardingRepository(this._apiClient);

  final ApiClient _apiClient;

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

  Future<void> registerUser(OnboardingState state) async {
    final role = state.role;
    if (role == null) {
      throw ApiException('Veuillez choisir un rôle avant de continuer.');
    }

    await _apiClient.post('/users/register', {
      'phone': state.phone.trim(),
      'fullName': state.fullName.trim(),
      'role': role.wireValue,
      'districtId': state.district!.id,
      'idCardStorageKey': state.idCardStorageKey,
      if (role == UserRole.craftsman && state.serviceCategory != null)
        'serviceCategory': state.serviceCategory!.wireValue,
      if (role == UserRole.craftsman)
        'experienceDetails': state.experienceDetails.trim(),
      if (state.isPhoneVerified && state.firebaseIdToken != null)
        'firebaseIdToken': state.firebaseIdToken,
    });
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
  (ref) => OnboardingRepository(ref.watch(apiClientProvider)),
);

// Fetched once per app session — the registration screen's district
// dropdown watches this instead of a hardcoded list, since the founder can
// add new districts from the admin panel at any time.
final districtsProvider = FutureProvider<List<District>>(
  (ref) => ref.watch(onboardingRepositoryProvider).getDistricts(),
);
