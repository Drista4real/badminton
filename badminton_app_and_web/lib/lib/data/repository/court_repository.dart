import 'dart:async';
import 'dart:convert';

import '../models/court_model.dart';
import '../network/api_client.dart';

class CourtRepository {
  CourtRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<CourtModel>> fetchActiveCourts({String? searchText}) async {
    try {
      final response = await _apiClient.getJson(
        '/api/courts',
        queryParameters: {'q': searchText},
        requireAuth: true,
      );

      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CourtApiException(
          _extractError(body) ?? _messageForStatus(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      if (body is! Map<String, dynamic>) {
        throw const CourtApiException('Phản hồi danh sách sân không hợp lệ.');
      }

      final rawItems = body['items'];
      if (rawItems is! Iterable) {
        throw const CourtApiException('Backend không trả về danh sách sân.');
      }

      final courts = rawItems
          .whereType<Map>()
          .map((item) => CourtModel.fromJson(Map<String, dynamic>.from(item)))
          .where((court) => court.isActive && !court.isMaintenance)
          .toList();

      courts.sort((left, right) {
        final leftName = left.code.isNotEmpty ? left.code : left.name;
        final rightName = right.code.isNotEmpty ? right.code : right.name;
        return leftName.compareTo(rightName);
      });

      return courts;
    } on TimeoutException {
      throw const CourtApiException('Kết nối backend quá thời gian chờ.');
    } on CourtApiException {
      rethrow;
    } on ApiAuthenticationException catch (error) {
      throw CourtApiException(error.message);
    } catch (_) {
      throw const CourtApiException('Không thể kết nối backend danh sách sân.');
    }
  }

  Object? _decodeBody(String rawBody) {
    if (rawBody.isEmpty) return null;
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return null;
    }
  }

  String? _extractError(Object? body) {
    if (body is Map) {
      return body['message']?.toString();
    }
    return null;
  }

  String _messageForStatus(int statusCode) {
    if (statusCode == 401) {
      return 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.';
    }
    if (statusCode == 403) {
      return 'Tài khoản không có quyền xem danh sách sân.';
    }
    if (statusCode >= 500) {
      return 'Backend không tải được danh sách sân. Kiểm tra log backend.';
    }
    return 'Không tải được danh sách sân.';
  }
}

class CourtApiException implements Exception {
  const CourtApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode;
    if (code == null) return message;
    return '$message (HTTP $code)';
  }
}
