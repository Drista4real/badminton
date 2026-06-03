import 'package:flutter/material.dart';

import 'model_json_helper.dart';

class WalletTransactionModel {
  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.status,
    this.description = '',
    this.sourceOrderId,
    this.providerTransactionId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final double amount;
  final String type;
  final String status;
  final String description;
  final String? sourceOrderId;
  final String? providerTransactionId;
  final DateTime? createdAt;

  bool get isCredit => amount >= 0;

  String get title {
    if (description.isNotEmpty) return description;
    switch (type) {
      case 'refund':
        return 'Hoàn tiền đơn hàng';
      case 'payment':
        return 'Thanh toán đặt sân';
      case 'reward':
        return 'Tích điểm đặt sân';
      case 'withdraw':
        return 'Yêu cầu rút tiền';
      default:
        return 'Giao dịch ví';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Hoàn thành';
      case 'pending':
        return 'Đang xử lý';
      case 'failed':
        return 'Thất bại';
      default:
        return status.isEmpty ? 'Hoàn thành' : status;
    }
  }

  Color get accentColor {
    if (type == 'refund' || isCredit) return const Color(0xFF4CAF50);
    if (type == 'withdraw' || status == 'pending') {
      return const Color(0xFFFF9800);
    }
    return const Color(0xFFEF5350);
  }

  IconData get icon {
    if (type == 'refund' || isCredit) return Icons.add_circle_rounded;
    if (type == 'withdraw') return Icons.account_balance_rounded;
    return Icons.remove_circle_rounded;
  }

  factory WalletTransactionModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) {
    return WalletTransactionModel(
      id: id,
      userId: json['userId'] as String? ?? '',
      amount: ModelJsonHelper.doubleFromJson(json['amount']),
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
      description: json['description'] as String? ?? '',
      sourceOrderId: json['sourceOrderId'] as String?,
      providerTransactionId: json['providerTransactionId'] as String?,
      createdAt: ModelJsonHelper.dateTimeFromJson(json['createdAt']),
    );
  }
}

class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.points,
    required this.availableBalance,
    required this.pendingWithdrawal,
  });

  final double balance;
  final int points;
  final double availableBalance;
  final double pendingWithdrawal;

  static const empty = WalletSummary(
    balance: 0,
    points: 0,
    availableBalance: 0,
    pendingWithdrawal: 0,
  );

  factory WalletSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WalletSummary.empty;
    final pointsValue = json['points'] ?? json['loyaltyPoints'];
    final balance = ModelJsonHelper.doubleFromJson(json['walletBalance']);
    final pendingWithdrawal = ModelJsonHelper.doubleFromJson(
      json['pendingWithdrawal'],
    );
    final availableBalance = json.containsKey('availableBalance')
        ? ModelJsonHelper.doubleFromJson(json['availableBalance'])
        : balance - pendingWithdrawal;

    return WalletSummary(
      balance: balance,
      points: ModelJsonHelper.intFromJson(pointsValue),
      availableBalance: availableBalance,
      pendingWithdrawal: pendingWithdrawal,
    );
  }
}
