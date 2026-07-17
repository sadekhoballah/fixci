import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/models/user_role.dart';
import 'onboarding_state.dart';

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void selectRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  void setFullName(String value) {
    state = state.copyWith(fullName: value);
  }

  void setPhone(String value) {
    state = state.copyWith(phone: value);
  }

  void setServiceCategory(ServiceCategory category) {
    state = state.copyWith(serviceCategory: category);
  }

  void setExperienceDetails(String value) {
    state = state.copyWith(experienceDetails: value);
  }

  void toggleIdCardAttached() {
    state = state.copyWith(idCardAttached: !state.idCardAttached);
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
