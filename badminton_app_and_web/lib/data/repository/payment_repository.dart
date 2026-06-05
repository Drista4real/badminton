import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/wallet_transaction_model.dart';
import '../network/api_client.dart';

class PaymentRepository {
  PaymentRepository({FirebaseFirestore? firestore, ApiClient? apiClient})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _apiClient = apiClient ?? ApiClient.instance;

  final FirebaseFirestore _firestore;
  final ApiClient _apiClient;

  Stream<WalletSummary> watchWalletSummary(String userId) {
    return _firestore.collection('users').doc(userId.trim()).snapshots().map((
      doc,
    ) {
      return WalletSummary.fromJson(doc.data());
    });
  }

  Future<PaymentBenefitResult> applyAppPaymentBenefits({
    required String userId,
    required String orderId,
    required double originalAmount,
    required bool useWallet,
    required bool usePoints,
    required List<String> bookingIds,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedOrderId = orderId.trim();
    if (trimmedUserId.isEmpty || trimmedOrderId.isEmpty) {
      throw const PaymentRepositoryException('Thiếu thông tin thanh toán.');
    }

    try {
      final response = await _apiClient
          .postJson('/api/payment/apply-benefits', {
            'orderId': trimmedOrderId,
            'originalAmount': originalAmount,
            'useWallet': useWallet,
            'usePoints': usePoints,
            'bookingIds': bookingIds,
          });

      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PaymentRepositoryException(
          _extractError(body) ?? 'KhÃ´ng thá»ƒ Ã¡p dá»¥ng vÃ­/Ä‘iá»ƒm.',
        );
      }

      if (body is! Map<String, dynamic>) {
        throw const PaymentRepositoryException(
          'Backend tráº£ vá» káº¿t quáº£ thanh toÃ¡n khÃ´ng há»£p lá»‡.',
        );
      }

      return PaymentBenefitResult(
        originalAmount: _doubleValue(body['originalAmount']),
        payableAmount: _doubleValue(body['payableAmount']),
        walletDiscount: _doubleValue(body['walletDiscount']),
        pointDiscount: _doubleValue(body['pointDiscount']),
        pointsSpent: _intValue(body['pointsSpent']),
        isFullyPaid: body['isFullyPaid'] == true,
      );
    } on TimeoutException {
      throw const PaymentRepositoryException(
        'Káº¿t ná»‘i backend quÃ¡ thá»i gian chá».',
      );
    } on PaymentRepositoryException {
      rethrow;
    } catch (_) {
      throw const PaymentRepositoryException(
        'KhÃ´ng thá»ƒ káº¿t ná»‘i backend thanh toÃ¡n.',
      );
    }

  }

  Future<void> cancelPendingOrder({
    required String userId,
    required String orderId,
    required List<String> bookingIds,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedOrderId = orderId.trim();
    if (trimmedUserId.isEmpty || trimmedOrderId.isEmpty) return;

    try {
      final response = await _apiClient.postJson(
        '/api/payment/cancel-pending',
        {'orderId': trimmedOrderId, 'bookingIds': bookingIds},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
    } catch (_) {
      // Fall back to the legacy Firestore transaction below when the backend
      // endpoint is not available yet.
    }

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(trimmedUserId);
      final orderRef = _firestore.collection('orders').doc(trimmedOrderId);
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) return;

      final orderData = Map<String, dynamic>.from(
        orderSnapshot.data() ?? <String, dynamic>{},
      );
      final orderUserId = orderData['userId']?.toString() ?? '';
      if (orderUserId != trimmedUserId) {
        throw const PaymentRepositoryException(
          'Tài khoản không có quyền hủy đơn hàng này.',
        );
      }

      final status = orderData['status']?.toString().toLowerCase() ?? '';
      if (status != 'pending') return;

      final now = FieldValue.serverTimestamp();
      final walletDiscount = _doubleValue(orderData['appWalletDiscount']);
      final pointsSpent = _intValue(orderData['appPointsSpent']);
      final benefitsRefunded = orderData['appBenefitsRefunded'] == true;
      final shouldRefundBenefits =
          (walletDiscount > 0 || pointsSpent > 0) && !benefitsRefunded;
      final resolvedBookingIds = _resolveBookingIds(orderData, bookingIds);
      final bookingRefs = resolvedBookingIds
          .map((bookingId) => _firestore.collection('bookings').doc(bookingId))
          .toList();
      final bookingSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final bookingRef in bookingRefs) {
        bookingSnapshots.add(await transaction.get(bookingRef));
      }
      final userSnapshot = shouldRefundBenefits
          ? await transaction.get(userRef)
          : null;
      final userData = Map<String, dynamic>.from(
        userSnapshot?.data() ?? <String, dynamic>{},
      );

      transaction.set(orderRef, {
        'status': 'cancelled',
        'orderStatus': 'cancelled',
        'paymentStatus': 'cancelled',
        'cancelledReason': 'user_cancelled',
        'cancelledAt': now,
        'updatedAt': now,
        if (shouldRefundBenefits) 'appBenefitsRefunded': true,
      }, SetOptions(merge: true));

      for (final bookingRef in bookingRefs) {
        transaction.set(bookingRef, {
          'status': 'cancelled',
          'orderStatus': 'cancelled',
          'paymentStatus': 'cancelled',
          'cancelledReason': 'user_cancelled',
          'cancelledAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }

      for (final slotLockId in _buildSlotLockIds(bookingSnapshots)) {
        transaction.delete(
          _firestore.collection('bookingSlotLocks').doc(slotLockId),
        );
      }

      if (!shouldRefundBenefits) return;

      if (walletDiscount > 0) {
        final walletBalance = _doubleValue(userData['walletBalance']);
        final pendingWithdrawal = math.max(
          0,
          _doubleValue(userData['pendingWithdrawal']),
        );
        final newWalletBalance = walletBalance + walletDiscount;
        transaction.set(userRef, {
          'walletBalance': newWalletBalance,
          'availableBalance': newWalletBalance - pendingWithdrawal,
          'updatedAt': now,
        }, SetOptions(merge: true));

        final walletTransactionRef = _firestore
            .collection('walletTransactions')
            .doc('refund_${trimmedOrderId}_app_benefits');
        transaction.set(walletTransactionRef, {
          'userId': trimmedUserId,
          'amount': walletDiscount,
          'type': 'refund',
          'status': 'completed',
          'description': 'Hoàn ví do hủy đơn chưa thanh toán',
          'sourceOrderId': trimmedOrderId,
          'provider': 'app_wallet',
          'createdAt': now,
        }, SetOptions(merge: true));
      }

      if (pointsSpent > 0) {
        final currentPoints = _intValue(
          userData['points'] ?? userData['loyaltyPoints'],
        );
        transaction.set(userRef, {
          'points': currentPoints + pointsSpent,
          'loyaltyPoints': currentPoints + pointsSpent,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }
    });
  }

  Future<PaymentQrResult> generatePaymentQr({required String orderId}) async {
    try {
      final response = await _apiClient.postJson('/api/payment/generate-qr', {
        'orderId': orderId,
      });

      final body = _decodeBody(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PaymentRepositoryException(
          _extractError(body) ?? 'Không tạo được mã QR thanh toán.',
        );
      }

      if (body is! Map<String, dynamic>) {
        throw const PaymentRepositoryException(
          'Backend trả về dữ liệu QR không hợp lệ.',
        );
      }

      final qrUrl =
          body['qrUrl']?.toString() ?? body['QrUrl']?.toString() ?? '';
      if (qrUrl.isEmpty) {
        throw const PaymentRepositoryException('Backend không trả về QR URL.');
      }

      return PaymentQrResult(
        qrUrl: qrUrl,
        paymentContent:
            body['paymentContent']?.toString() ??
            body['PaymentContent']?.toString() ??
            orderId,
      );
    } on TimeoutException {
      throw const PaymentRepositoryException(
        'Kết nối backend quá thời gian chờ.',
      );
    } on PaymentRepositoryException {
      rethrow;
    } catch (_) {
      throw const PaymentRepositoryException(
        'Không thể kết nối backend thanh toán.',
      );
    }
  }

  Future<PaymentReconcileResult> reconcilePayment({
    required String orderId,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/payment/reconcile', {
        'orderId': orderId,
      });

      final body = _decodeBody(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PaymentRepositoryException(
          _extractError(body) ?? 'Không kiểm tra được thanh toán.',
        );
      }

      if (body is! Map<String, dynamic>) {
        throw const PaymentRepositoryException(
          'Backend trả về trạng thái thanh toán không hợp lệ.',
        );
      }

      return PaymentReconcileResult(
        isPaid: body['isPaid'] == true,
        pollingConfigured: body['pollingConfigured'] != false,
        message: body['message']?.toString(),
      );
    } on TimeoutException {
      throw const PaymentRepositoryException(
        'Kết nối backend quá thời gian chờ.',
      );
    } on PaymentRepositoryException {
      rethrow;
    } catch (_) {
      throw const PaymentRepositoryException(
        'Không thể kết nối backend thanh toán.',
      );
    }
  }

  Stream<PaymentOrderStatus> watchOrderStatus(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((snapshot) => PaymentOrderStatus.fromJson(snapshot.data()));
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

  static double _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _resolveBookingIds(
    Map<String, dynamic> orderData,
    List<String> fallback,
  ) {
    final rawBookingIds = orderData['bookingIds'];
    if (rawBookingIds is Iterable) {
      return rawBookingIds
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return fallback
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static Iterable<String> _buildSlotLockIds(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> bookingSnapshots,
  ) sync* {
    final emitted = <String>{};
    for (final bookingSnapshot in bookingSnapshots) {
      final bookingData = bookingSnapshot.data();
      if (bookingData == null) continue;

      final courtId = bookingData['courtId']?.toString() ?? '';
      final date = _dateOnly(bookingData['date']);
      final startTime = _intValue(bookingData['startTime']);
      final endTime = _intValue(bookingData['endTime']);
      if (courtId.trim().isEmpty ||
          date == null ||
          startTime >= endTime ||
          startTime < 0) {
        continue;
      }

      for (var slotStart = startTime; slotStart < endTime; slotStart += 30) {
        final id =
            '${_sanitizeDocumentId(courtId)}_${_formatDateId(date)}_${slotStart.toString().padLeft(4, '0')}';
        if (emitted.add(id)) {
          yield id;
        }
      }
    }
  }

  static DateTime? _dateOnly(Object? value) {
    DateTime? dateTime;
    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    } else if (value is String) {
      dateTime = DateTime.tryParse(value);
    }

    if (dateTime == null) return null;
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static String _formatDateId(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _sanitizeDocumentId(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.trim().codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isUpper = codeUnit >= 65 && codeUnit <= 90;
      final isLower = codeUnit >= 97 && codeUnit <= 122;
      final isDash = codeUnit == 45;
      final isUnderscore = codeUnit == 95;
      buffer.write(
        isDigit || isUpper || isLower || isDash || isUnderscore
            ? String.fromCharCode(codeUnit)
            : '_',
      );
    }
    return buffer.toString();
  }
}

class PaymentBenefitResult {
  const PaymentBenefitResult({
    required this.originalAmount,
    required this.payableAmount,
    required this.walletDiscount,
    required this.pointDiscount,
    required this.pointsSpent,
    required this.isFullyPaid,
  });

  final double originalAmount;
  final double payableAmount;
  final double walletDiscount;
  final double pointDiscount;
  final int pointsSpent;
  final bool isFullyPaid;
}

class PaymentQrResult {
  const PaymentQrResult({required this.qrUrl, required this.paymentContent});

  final String qrUrl;
  final String paymentContent;
}

class PaymentReconcileResult {
  const PaymentReconcileResult({
    required this.isPaid,
    required this.pollingConfigured,
    this.message,
  });

  final bool isPaid;
  final bool pollingConfigured;
  final String? message;
}

class PaymentOrderStatus {
  const PaymentOrderStatus({required this.isPaid});

  factory PaymentOrderStatus.fromJson(Map<String, dynamic>? data) {
    final status = data?['status']?.toString().toLowerCase();
    final orderStatus = data?['orderStatus']?.toString().toLowerCase();
    final paymentStatus = data?['paymentStatus']?.toString().toLowerCase();

    return PaymentOrderStatus(
      isPaid:
          status == 'paid' ||
          status == 'confirmed' ||
          orderStatus == 'paid' ||
          orderStatus == 'confirmed' ||
          paymentStatus == 'success',
    );
  }

  final bool isPaid;
}

class PaymentRepositoryException implements Exception {
  const PaymentRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
