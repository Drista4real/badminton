import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/date_format.dart';
import '../models/booking_model.dart';
import '../network/api_client.dart';

class BookingRepository {
  BookingRepository({FirebaseFirestore? firestore, ApiClient? apiClient})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _apiClient = apiClient ?? ApiClient.instance;

  final FirebaseFirestore _firestore;
  final ApiClient _apiClient;

  Stream<List<BookingModel>> watchActiveBookings() async* {
    yield await fetchActiveBookings();
    yield* Stream<void>.periodic(
      const Duration(seconds: 30),
    ).asyncMap((_) => fetchActiveBookings());
  }

  Stream<List<BookingModel>> watchUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap(_bookingsFromSnapshotWithOrderPrices);
  }

  Future<List<BookingModel>> fetchActiveBookings() async {
    try {
      final response = await _apiClient.getJson(
        '/api/bookings/active',
        requireAuth: true,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiExceptionFromResponse(
          response.statusCode,
          response.body,
          'KhÃ´ng thá»ƒ táº£i lá»‹ch Ä‘áº·t sÃ¢n.',
        );
      }

      final body = _decodeBody(response.body);
      if (body is! Map<String, dynamic>) {
        throw const BookingApiException(
          'Pháº£n há»“i lá»‹ch Ä‘áº·t sÃ¢n khÃ´ng há»£p lá»‡.',
        );
      }

      final rawItems = body['items'];
      if (rawItems is! Iterable) {
        return const <BookingModel>[];
      }

      return rawItems
          .whereType<Map>()
          .map((item) => BookingModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on TimeoutException {
      throw const BookingApiException(
        'Káº¿t ná»‘i backend quÃ¡ thá»i gian chá».',
      );
    } on BookingApiException {
      rethrow;
    } catch (_) {
      throw const BookingApiException(
        'KhÃ´ng thá»ƒ káº¿t ná»‘i backend Ä‘áº·t sÃ¢n.',
      );
    }
  }

  Future<void> cancelFixedBookingByUser(
    String bookingId, {
    String? orderId,
  }) async {
    final resolvedOrderId = orderId?.isNotEmpty == true
        ? orderId!
        : await _resolveOrderIdFromBooking(bookingId);

    try {
      final response = await _apiClient.postJson('/api/bookings/cancel', {
        'orderId': resolvedOrderId,
      });

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiExceptionFromResponse(
          response.statusCode,
          response.body,
          'Không thể hủy đơn đặt sân.',
        );
      }
    } on TimeoutException {
      throw const BookingApiException('Kết nối backend quá thời gian chờ.');
    } on BookingApiException {
      rethrow;
    } catch (_) {
      throw const BookingApiException('Không thể kết nối backend đặt sân.');
    }
  }

  Future<ReportFixedAbsenceApiResult> reportFixedAbsence({
    required String bookingId,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/bookings/report-absence',
        {'bookingId': bookingId},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiExceptionFromResponse(
          response.statusCode,
          response.body,
          'Không thể báo nghỉ buổi này.',
        );
      }

      final body = _decodeBody(response.body);
      if (body is! Map<String, dynamic>) {
        throw const BookingApiException('Phản hồi báo nghỉ không hợp lệ.');
      }

      return ReportFixedAbsenceApiResult(
        bookingId: body['bookingId']?.toString() ?? bookingId,
        orderId: body['orderId']?.toString() ?? '',
        refundedAmount: (body['refundedAmount'] as num?)?.toDouble() ?? 0,
        absenceCountThisMonth:
            (body['absenceCountThisMonth'] as num?)?.toInt() ?? 0,
      );
    } on TimeoutException {
      throw const BookingApiException('Kết nối backend quá thời gian chờ.');
    } on BookingApiException {
      rethrow;
    } catch (_) {
      throw const BookingApiException('Không thể kết nối backend đặt sân.');
    }
  }

  Future<CancelWithRefundApiResult> cancelBookingWithRefund({
    required String orderId,
    required String refundMethod,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    try {
      final payload = <String, Object>{
        'orderId': orderId,
        'refundMethod': refundMethod,
      };
      if (bankName != null) {
        payload['bankName'] = bankName;
      }
      if (bankAccountNumber != null) {
        payload['bankAccountNumber'] = bankAccountNumber;
      }
      if (bankAccountName != null) {
        payload['bankAccountName'] = bankAccountName;
      }

      final response = await _apiClient.postJson(
        '/api/bookings/cancel-with-refund',
        payload,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiExceptionFromResponse(
          response.statusCode,
          response.body,
          'Không thể hủy đơn đặt sân.',
        );
      }

      final body = _decodeBody(response.body);
      if (body is! Map<String, dynamic>) {
        throw const BookingApiException('Phản hồi hủy đơn không hợp lệ.');
      }

      return CancelWithRefundApiResult(
        orderId: body['orderId']?.toString() ?? orderId,
        status: body['status']?.toString() ?? '',
        refundMethod: body['refundMethod']?.toString() ?? refundMethod,
        refundAmount: (body['refundAmount'] as num?)?.toDouble() ?? 0,
        refundRate: (body['refundRate'] as num?)?.toDouble() ?? 0,
        refundedToWallet: body['refundedToWallet'] == true,
      );
    } on TimeoutException {
      throw const BookingApiException('Kết nối backend quá thời gian chờ.');
    } on BookingApiException {
      rethrow;
    } catch (_) {
      throw const BookingApiException('Không thể kết nối backend đặt sân.');
    }
  }

  Future<CreateBookingApiResult> createBookingViaApi({
    required String courtId,
    required DateTime date,
    required int startTime,
    required int endTime,
    required double totalPrice,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/bookings/create', {
        'courtId': courtId,
        'date': DateFormatUtils.apiDate(date),
        'startTime': startTime,
        'endTime': endTime,
        'totalPrice': totalPrice,
      });

      if (response.statusCode == 409) {
        throw const BookingConflictException();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiExceptionFromResponse(
          response.statusCode,
          response.body,
          'Không thể tạo đơn đặt sân.',
        );
      }

      final body = _decodeBody(response.body);
      if (body is! Map<String, dynamic>) {
        throw const BookingApiException('Phản hồi đặt sân không hợp lệ.');
      }

      final orderId = body['orderId']?.toString() ?? '';
      final rawBookingIds = body['bookingIds'];
      final bookingIds = rawBookingIds is Iterable
          ? rawBookingIds.map((item) => item.toString()).toList()
          : <String>[];

      if (orderId.isEmpty) {
        throw const BookingApiException('Backend không trả về mã đơn đặt sân.');
      }

      return CreateBookingApiResult(
        orderId: orderId,
        bookingIds: bookingIds,
        totalPrice: (body['totalPrice'] as num?)?.toDouble() ?? totalPrice,
      );
    } on TimeoutException {
      throw const BookingApiException('Kết nối backend quá thời gian chờ.');
    } on BookingApiException {
      rethrow;
    } catch (_) {
      throw const BookingApiException('Không thể kết nối backend đặt sân.');
    }
  }

  Future<CreateBookingApiResult> createFixedBookingViaApi({
    required String courtId,
    required DateTime startDate,
    required int months,
    required List<int> daysOfWeek,
    required int startTime,
    required int endTime,
    required double totalPrice,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/bookings/create-fixed', {
        'courtId': courtId,
        'startDate': DateFormatUtils.apiDate(startDate),
        'months': months,
        'daysOfWeek': daysOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'totalPrice': totalPrice,
      });

      if (response.statusCode == 409) {
        throw const BookingConflictException();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiExceptionFromResponse(
          response.statusCode,
          response.body,
          'Không thể tạo lịch cố định.',
        );
      }

      final body = _decodeBody(response.body);
      if (body is! Map<String, dynamic>) {
        throw const BookingApiException(
          'Phản hồi đặt lịch cố định không hợp lệ.',
        );
      }

      final orderId = body['orderId']?.toString() ?? '';
      final rawBookingIds = body['bookingIds'];
      final bookingIds = rawBookingIds is Iterable
          ? rawBookingIds.map((item) => item.toString()).toList()
          : <String>[];

      if (orderId.isEmpty) {
        throw const BookingApiException('Backend không trả về mã đơn đặt sân.');
      }

      return CreateBookingApiResult(
        orderId: orderId,
        bookingIds: bookingIds,
        totalPrice: (body['totalPrice'] as num?)?.toDouble() ?? totalPrice,
      );
    } on TimeoutException {
      throw const BookingApiException('Kết nối backend quá thời gian chờ.');
    } on BookingApiException {
      rethrow;
    } catch (_) {
      throw const BookingApiException('Không thể kết nối backend đặt sân.');
    }
  }

  Future<RenewFixedBookingApiResult> renewFixedBookingViaApi({
    required String oldOrderId,
    required int durationMonths,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/bookings/renew-fixed', {
        'oldOrderId': oldOrderId,
        'durationMonths': durationMonths,
      });

      if (response.statusCode == 409) {
        throw const BookingConflictException();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiExceptionFromResponse(
          response.statusCode,
          response.body,
          'Không thể gia hạn lịch cố định.',
        );
      }

      final body = _decodeBody(response.body);
      if (body is! Map<String, dynamic>) {
        throw const BookingApiException(
          'Phản hồi gia hạn lịch cố định không hợp lệ.',
        );
      }

      final orderId =
          body['newOrderId']?.toString() ?? body['orderId']?.toString() ?? '';
      final rawBookingIds = body['bookingIds'];
      final bookingIds = rawBookingIds is Iterable
          ? rawBookingIds.map((item) => item.toString()).toList()
          : <String>[];

      if (orderId.isEmpty) {
        throw const BookingApiException('Backend không trả về mã đơn gia hạn.');
      }

      return RenewFixedBookingApiResult(
        orderId: orderId,
        bookingIds: bookingIds,
        totalPrice: (body['totalPrice'] as num?)?.toDouble() ?? 0,
      );
    } on TimeoutException {
      throw const BookingApiException('Kết nối backend quá thời gian chờ.');
    } on BookingApiException {
      rethrow;
    } catch (_) {
      throw const BookingApiException('Không thể kết nối backend đặt sân.');
    }
  }

  List<BookingModel> _bookingsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] ??= doc.id;
      return BookingModel.fromJson(data);
    }).toList();
  }

  Future<List<BookingModel>> _bookingsFromSnapshotWithOrderPrices(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final bookings = _bookingsFromSnapshot(snapshot);
    final missingPriceOrderIds = bookings
        .where((booking) {
          final orderId = booking.orderId;
          return booking.totalPrice <= 0 &&
              orderId != null &&
              orderId.isNotEmpty;
        })
        .map((booking) => booking.orderId!)
        .toSet();

    if (missingPriceOrderIds.isEmpty) {
      return bookings;
    }

    final orderSnapshots = await Future.wait(
      missingPriceOrderIds.map((orderId) {
        return _firestore.collection('orders').doc(orderId).get();
      }),
    );

    final pricesByOrderId = <String, double>{};
    for (final orderSnapshot in orderSnapshots) {
      final data = orderSnapshot.data();
      if (data == null) {
        continue;
      }

      final totalPrice = data['totalPrice'];
      if (totalPrice is num) {
        pricesByOrderId[orderSnapshot.id] = totalPrice.toDouble();
      }
    }

    return bookings.map((booking) {
      final orderId = booking.orderId;
      final orderPrice = orderId == null ? null : pricesByOrderId[orderId];
      if (booking.totalPrice > 0 || orderPrice == null) {
        return booking;
      }

      return booking.copyWith(totalPrice: orderPrice);
    }).toList();
  }

  Future<String> _resolveOrderIdFromBooking(String bookingId) async {
    final snapshot = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    final orderId = snapshot.data()?['orderId']?.toString() ?? '';
    if (orderId.isEmpty) {
      throw const BookingApiException('Booking does not contain orderId.');
    }

    return orderId;
  }

  Object? _decodeBody(String rawBody) {
    if (rawBody.isEmpty) return null;
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return null;
    }
  }

  BookingApiException _apiExceptionFromResponse(
    int statusCode,
    String rawBody,
    String fallback,
  ) {
    final backendMessage = _extractError(_decodeBody(rawBody));
    return BookingApiException(
      backendMessage ?? _messageForStatus(statusCode, fallback),
      statusCode: statusCode,
    );
  }

  String? _extractError(Object? body) {
    if (body is Map) {
      return body['message']?.toString();
    }
    return null;
  }

  String _messageForStatus(int statusCode, String fallback) {
    if (statusCode == 307 || statusCode == 308) {
      return 'Backend đang chuyển hướng HTTPS. Hãy chạy backend bằng profile http hoặc cấu hình API_BASE_URL đúng.';
    }

    if (statusCode == 401) {
      return 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.';
    }

    if (statusCode == 403) {
      return 'Tài khoản không có quyền thực hiện thao tác này.';
    }

    if (statusCode >= 500) {
      return 'Backend không tạo được đơn đặt sân. Kiểm tra log backend để xem lỗi cấu hình hoặc dữ liệu Firestore.';
    }

    return fallback;
  }
}

class CreateBookingApiResult {
  const CreateBookingApiResult({
    required this.orderId,
    required this.bookingIds,
    required this.totalPrice,
  });

  final String orderId;
  final List<String> bookingIds;
  final double totalPrice;
}

class RenewFixedBookingApiResult {
  const RenewFixedBookingApiResult({
    required this.orderId,
    required this.bookingIds,
    required this.totalPrice,
  });

  final String orderId;
  final List<String> bookingIds;
  final double totalPrice;
}

class ReportFixedAbsenceApiResult {
  const ReportFixedAbsenceApiResult({
    required this.bookingId,
    required this.orderId,
    required this.refundedAmount,
    required this.absenceCountThisMonth,
  });

  final String bookingId;
  final String orderId;
  final double refundedAmount;
  final int absenceCountThisMonth;
}

class CancelWithRefundApiResult {
  const CancelWithRefundApiResult({
    required this.orderId,
    required this.status,
    required this.refundMethod,
    required this.refundAmount,
    required this.refundRate,
    required this.refundedToWallet,
  });

  final String orderId;
  final String status;
  final String refundMethod;
  final double refundAmount;
  final double refundRate;
  final bool refundedToWallet;
}

class BookingApiException implements Exception {
  const BookingApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode;
    if (code == null) return message;
    return '$message (HTTP $code)';
  }
}

class BookingConflictException extends BookingApiException {
  const BookingConflictException()
    : super('Court is already booked for this time range.');
}
