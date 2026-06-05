import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static final ApiClient instance = ApiClient();

  final http.Client _client;

  String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return 'http://localhost:5011';

    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5011'
        : 'http://localhost:5011';
  }

  Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
    bool requireAuth = false,
  }) async {
    final headers = await _jsonHeaders(requireAuth: requireAuth);

    return _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }

  Future<http.Response> getJson(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Duration timeout = const Duration(seconds: 20),
    bool requireAuth = false,
  }) async {
    final headers = await _jsonHeaders(requireAuth: requireAuth);
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: _cleanQueryParameters(queryParameters));

    return _client.get(uri, headers: headers).timeout(timeout);
  }

  Future<Map<String, String>> _jsonHeaders({required bool requireAuth}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    } else if (requireAuth) {
      throw const ApiAuthenticationException(
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
    }

    return headers;
  }

  Map<String, String>? _cleanQueryParameters(Map<String, String?> parameters) {
    final cleaned = <String, String>{};
    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        cleaned[entry.key] = value;
      }
    }
    return cleaned.isEmpty ? null : cleaned;
  }

  void close() {
    _client.close();
  }
}

class ApiAuthenticationException implements Exception {
  const ApiAuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}
