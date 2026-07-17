import '../../core/models/service_category.dart';
import '../../core/models/user_role.dart';

class OnboardingState {
  const OnboardingState({
    this.role,
    this.fullName = '',
    this.phone = '',
    this.serviceCategory,
    this.experienceDetails = '',
    this.idCardAttached = false,
  });

  final UserRole? role;
  final String fullName;
  final String phone;
  final ServiceCategory? serviceCategory;
  final String experienceDetails;
  final bool idCardAttached;

  bool get isRegistrationComplete {
    if (phone.trim().isEmpty) return false;
    if (role == UserRole.craftsman) return serviceCategory != null;
    return true;
  }

  OnboardingState copyWith({
    UserRole? role,
    String? fullName,
    String? phone,
    ServiceCategory? serviceCategory,
    String? experienceDetails,
    bool? idCardAttached,
  }) {
    return OnboardingState(
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      experienceDetails: experienceDetails ?? this.experienceDetails,
      idCardAttached: idCardAttached ?? this.idCardAttached,
    );
  }
}
