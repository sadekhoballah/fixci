import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_token_storage.dart';

enum AdminAuthStatus { checking, loggedOut, loggedIn }

class AdminAuthState {
  const AdminAuthState({
    this.status = AdminAuthStatus.checking,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AdminAuthStatus status;
  final bool isSubmitting;
  final String? errorMessage;

  AdminAuthState copyWith({
    AdminAuthStatus? status,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AdminAuthController extends Notifier<AdminAuthState> {
  @override
  AdminAuthState build() {
    Future.microtask(_restoreSession);
    return const AdminAuthState();
  }

  // A cached token is optimistic — it may have expired (tokens are issued
  // for 12h) or the account may have been deactivated since. The first
  // request that comes back 401 will bounce the user back to the login
  // screen (see AdminKycController), so there's no need to validate it here.
  Future<void> _restoreSession() async {
    final token = await ref.read(adminTokenStorageProvider).loadToken();
    if (token == null) {
      state = state.copyWith(status: AdminAuthStatus.loggedOut);
      return;
    }
    ref.read(adminApiClientProvider).token = token;
    state = state.copyWith(status: AdminAuthStatus.loggedIn);
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await ref
          .read(adminApiClientProvider)
          .post('/admin-auth/login', {
            'username': username,
            'password': password,
          });
      final token = response['token'] as String;
      await ref.read(adminTokenStorageProvider).saveToken(token);
      ref.read(adminApiClientProvider).token = token;
      state = state.copyWith(
        isSubmitting: false,
        status: AdminAuthStatus.loggedIn,
      );
    } on AdminApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Une erreur inattendue est survenue.',
      );
    }
  }

  Future<void> logout() async {
    await ref.read(adminTokenStorageProvider).clearToken();
    ref.read(adminApiClientProvider).token = null;
    state = state.copyWith(status: AdminAuthStatus.loggedOut);
  }
}

final adminAuthControllerProvider =
    NotifierProvider<AdminAuthController, AdminAuthState>(
      AdminAuthController.new,
    );
