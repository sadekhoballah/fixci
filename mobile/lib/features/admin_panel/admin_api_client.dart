import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/network/api_config.dart';

class AdminApiException implements Exception {
  AdminApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

// Deliberately separate from the shared ApiClient: that one authenticates
// every request with a Firebase ID token (see current_auth_token.dart),
// which doesn't apply here — the admin dashboard logs in with
// username/password against POST /admin-auth/login and carries a plain JWT
// instead. Set via AdminAuthController once a login (or a cached token from
// AdminTokenStorage) is available.
class AdminApiClient {
  AdminApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  Map<String, String> _headers([Map<String, String> extra = const {}]) {
    return {if (token != null) 'Authorization': 'Bearer $token', ...extra};
  }

  Future<Map<String, dynamic>> get(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AdminApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    return _handleResponse(response);
  }

  Future<Uint8List> getBytes(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AdminApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw AdminApiException(
      'Une erreur est survenue (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers(const {'Content-Type': 'application/json'}),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AdminApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers(const {'Content-Type': 'application/json'}),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AdminApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final http.Response response;
    try {
      response = await _client
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers(
              body != null ? const {'Content-Type': 'application/json'} : const {},
            ),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AdminApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final rawDecoded = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    final decoded = rawDecoded is Map<String, dynamic>
        ? rawDecoded
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded['message'];
    throw AdminApiException(
      message is String
          ? message
          : message is List && message.isNotEmpty
          ? message.first.toString()
          : 'Une erreur est survenue (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}

final adminApiClientProvider = Provider<AdminApiClient>(
  (ref) => AdminApiClient(),
);
