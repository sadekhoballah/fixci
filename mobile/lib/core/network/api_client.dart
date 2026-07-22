import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../auth/dev_bypass_session.dart';
import '../platform/firebase_support.dart';
import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

// The Firebase ID token doubles as this app's bearer credential for every
// authenticated call (see api_client.dart usage below) — the SDK caches and
// auto-refreshes it, so fetching it fresh on every request is cheap and
// never goes stale.
Future<String?> _currentAuthToken() async {
  if (!isFirebaseSupportedPlatform) return null;
  await firebaseInitFuture;
  return FirebaseAuth.instance.currentUser?.getIdToken();
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, String>> _authHeaders([
    Map<String, String> extra = const {},
  ]) async {
    final token = await _currentAuthToken();
    if (token != null) {
      return {...extra, 'Authorization': 'Bearer $token'};
    }
    // No real Firebase session on this platform (see devBypassPhone) — fall
    // back to whatever phone the dev-bypass flow last knew about, if any.
    return {...extra, 'X-Dev-Phone': ?devBypassPhone};
  }

  Future<Map<String, dynamic>> get(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    return _handleResponse(response);
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
            headers: await _authHeaders(const {
              'Content-Type': 'application/json',
            }),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(
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
            headers: await _authHeaders(const {
              'Content-Type': 'application/json',
            }),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    String fieldName,
    List<int> bytes,
    String filename, {
    String? contentTypeHeader,
  }) async {
    final http.StreamedResponse streamed;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$path'),
      )
        ..headers.addAll(await _authHeaders())
        ..files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: filename,
            contentType: contentTypeHeader != null
                ? MediaType.parse(contentTypeHeader)
                : null,
          ),
        );
      streamed = await request.send().timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded['message'];
    throw ApiException(
      message is String
          ? message
          : message is List && message.isNotEmpty
          ? message.first.toString()
          : 'Une erreur est survenue (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
