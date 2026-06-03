import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/wallet_transaction_model.dart';
import '../network/api_client.dart';

class WalletRepository {
  WalletRepository({FirebaseFirestore? firestore, ApiClient? apiClient})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _apiClient = apiClient ?? ApiClient.instance;

  final FirebaseFirestore _firestore;
  final ApiClient _apiClient;

  Stream<WalletSummary> watchWalletSummary(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      return WalletSummary.fromJson(doc.data());
    });
  }

  Stream<List<WalletTransactionModel>> watchWalletTransactions(String userId) async* {
    yield await fetchWalletTransactions();
    yield* Stream<void>.periodic(const Duration(seconds: 30)).asyncMap(
      (_) => fetchWalletTransactions(),
    );
  }

  Future<List<WalletTransactionModel>> fetchWalletTransactions() async {
    final response = await _apiClient.getJson(
      '/api/wallet/transactions',
      requireAuth: true,
    );

    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WalletApiException(
        _extractError(body) ?? 'KhÃ´ng táº£i Ä‘Æ°á»£c lá»‹ch sá»­ giao dá»‹ch.',
      );
    }

    if (body is! Map<String, dynamic>) {
      throw const WalletApiException('Pháº£n há»“i giao dá»‹ch vÃ­ khÃ´ng há»£p lá»‡.');
    }

    final rawItems = body['items'];
    if (rawItems is! Iterable) {
      return const <WalletTransactionModel>[];
    }

    return rawItems
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final id = data['id']?.toString() ?? '';
          return WalletTransactionModel.fromJson(data, id: id);
        })
        .toList();
  }

  Future<WalletWithdrawResult> withdraw({
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final response = await _apiClient.postJson('/api/wallet/withdraw', {
      'amount': amount,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountName': bankAccountName,
    });

    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WalletApiException(
        _extractError(body) ?? 'Không thể tạo yêu cầu rút tiền.',
      );
    }

    if (body is! Map<String, dynamic>) {
      throw const WalletApiException('Phản hồi rút tiền không hợp lệ.');
    }

    return WalletWithdrawResult(
      transactionId: body['transactionId']?.toString() ?? '',
      newBalance: (body['newBalance'] as num?)?.toDouble() ?? 0,
      availableBalance: (body['availableBalance'] as num?)?.toDouble() ?? 0,
      pendingWithdrawal: (body['pendingWithdrawal'] as num?)?.toDouble() ?? 0,
    );
  }

  String? _extractError(Object? body) {
    if (body is Map) {
      return body['message']?.toString();
    }
    return null;
  }
}

class WalletWithdrawResult {
  const WalletWithdrawResult({
    required this.transactionId,
    required this.newBalance,
    required this.availableBalance,
    required this.pendingWithdrawal,
  });

  final String transactionId;
  final double newBalance;
  final double availableBalance;
  final double pendingWithdrawal;
}

class WalletApiException implements Exception {
  const WalletApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
