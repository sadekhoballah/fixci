import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../l10n/app_localizations.dart';
import '../auth/current_auth_token.dart';
import '../auth/dev_bypass_session.dart';
import '../localization/locale_controller.dart';
import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, required AppLocalizations l10n})
    : _client = client ?? http.Client(),
      _l10n = l10n;

  final http.Client _client;
  final AppLocalizations _l10n;

  Future<Map<String, String>> _authHeaders([
    Map<String, String> extra = const {},
  ]) async {
    final token = await currentAuthToken();
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
      throw ApiException(_l10n.networkConnectionErrorMessage);
    }
    return _handleResponse(response);
  }

  // Raw bytes rather than JSON — used for fetching a stored image (e.g. the
  // admin ID-card review endpoint) where the response body is the file
  // itself, not a JSON envelope.
  Future<Uint8List> getBytes(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(_l10n.networkConnectionErrorMessage);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(
      _l10n.genericErrorWithCode(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final http.Response response;
    try {
      response = await _client
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(_l10n.networkConnectionErrorMessage);
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
      throw ApiException(_l10n.networkConnectionErrorMessage);
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
      throw ApiException(_l10n.networkConnectionErrorMessage);
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
      throw ApiException(_l10n.networkConnectionErrorMessage);
    }
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    // A body of `null` (valid JSON for an endpoint like "my active job,
    // or none") isn't a Map — treat it the same as an empty body rather
    // than let the cast below throw.
    final rawDecoded = response.body.isEmpty ? null : jsonDecode(response.body);
    final decoded = rawDecoded is Map<String, dynamic>
        ? rawDecoded
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded['message'];
    throw ApiException(
      message is String
          ? message
          : message is List && message.isNotEmpty
          ? message.first.toString()
          : _l10n.genericErrorWithCode(response.statusCode),
      statusCode: response.statusCode,
    );
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(l10n: ref.watch(l10nProvider)),
);
