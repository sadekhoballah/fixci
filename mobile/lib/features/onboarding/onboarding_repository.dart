import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/media/id_card_picker.dart';
import '../../core/models/user_role.dart';
import 'onboarding_state.dart';

class OnboardingRepository {
  OnboardingRepository(this._apiClient);

  final ApiClient _apiClient;

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
      'idCardStorageKey': state.idCardStorageKey,
      if (role == UserRole.craftsman && state.serviceCategory != null)
        'serviceCategory': state.serviceCategory!.wireValue,
      if (role == UserRole.craftsman)
        'experienceDetails': state.experienceDetails.trim(),
      if (state.isPhoneVerified && state.firebaseIdToken != null)
        'firebaseIdToken': state.firebaseIdToken,
    });
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(apiClientProvider)),
);
