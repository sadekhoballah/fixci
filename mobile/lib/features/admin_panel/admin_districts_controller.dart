import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_districts_repository.dart';
import 'admin_districts_state.dart';

class AdminDistrictsController extends Notifier<AdminDistrictsState> {
  @override
  AdminDistrictsState build() {
    Future.microtask(refresh);
    return const AdminDistrictsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final districts = await ref
          .read(adminDistrictsRepositoryProvider)
          .getDistricts();
      state = state.copyWith(isLoading: false, districts: districts);
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les districts.',
      );
    }
  }

  Future<void> createDistrict(String name, String countryCode) async {
    try {
      await ref
          .read(adminDistrictsRepositoryProvider)
          .createDistrict(name, countryCode);
      await refresh();
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Une erreur est survenue.');
    }
  }

  Future<void> toggleArtisanRegistration(String id, bool value) =>
      _toggle(id, isArtisanRegistrationActive: value);

  Future<void> toggleClientOrdering(String id, bool value) =>
      _toggle(id, isClientOrderingActive: value);

  Future<void> _toggle(
    String id, {
    bool? isArtisanRegistrationActive,
    bool? isClientOrderingActive,
  }) async {
    if (state.processingDistrictIds.contains(id)) return;
    state = state.copyWith(
      processingDistrictIds: {...state.processingDistrictIds, id},
      clearError: true,
    );
    try {
      await ref
          .read(adminDistrictsRepositoryProvider)
          .updateToggles(
            id,
            isArtisanRegistrationActive: isArtisanRegistrationActive,
            isClientOrderingActive: isClientOrderingActive,
          );
      state = state.copyWith(
        districts: state.districts
            .map(
              (d) => d.id == id
                  ? d.copyWith(
                      isArtisanRegistrationActive:
                          isArtisanRegistrationActive,
                      isClientOrderingActive: isClientOrderingActive,
                    )
                  : d,
            )
            .toList(),
        processingDistrictIds: state.processingDistrictIds
            .where((existingId) => existingId != id)
            .toSet(),
      );
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(
        errorMessage: e.message,
        processingDistrictIds: state.processingDistrictIds
            .where((existingId) => existingId != id)
            .toSet(),
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Une erreur est survenue.',
        processingDistrictIds: state.processingDistrictIds
            .where((existingId) => existingId != id)
            .toSet(),
      );
    }
  }

  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminDistrictsControllerProvider =
    NotifierProvider<AdminDistrictsController, AdminDistrictsState>(
      AdminDistrictsController.new,
    );
