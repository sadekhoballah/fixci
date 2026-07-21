import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> get(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'))
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
            headers: const {'Content-Type': 'application/json'},
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
      )..files.add(
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
