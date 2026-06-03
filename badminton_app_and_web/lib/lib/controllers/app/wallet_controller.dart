import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/wallet_transaction_model.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/wallet_repository.dart';
import '../../routes/app_routes.dart';
import '../../utils/currency_format.dart';
import '../../utils/date_format.dart';

class WalletController extends GetxController {
  WalletController({
    required WalletRepository walletRepository,
    required AuthRepository authRepository,
  }) : _walletRepository = walletRepository,
       _authRepository = authRepository;

  final WalletRepository _walletRepository;
  final AuthRepository _authRepository;

  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final balance = 0.0.obs;
  final availableBalance = 0.0.obs;
  final pendingWithdrawal = 0.0.obs;
  final points = 0.obs;
  final transactions = <WalletTransactionModel>[].obs;
  final selectedWithdrawBank = RxnString();
  final isWithdrawing = false.obs;

  final withdrawAmountController = TextEditingController();
  final withdrawAccountController = TextEditingController();
  final withdrawNameController = TextEditingController();

  final withdrawBanks = const [
    'Vietcombank',
    'Techcombank',
    'BIDV',
    'VPBank',
    'MB Bank',
    'ACB',
    'Sacombank',
    'TPBank',
  ];

  StreamSubscription<WalletSummary>? _summarySub;
  StreamSubscription<List<WalletTransactionModel>>? _transactionsSub;

  String get userId {
    final user = _authRepository.currentUser;
    if (user == null || user.uid.isEmpty || user.isAnonymous) {
      Get.offAllNamed(AppRoutes.login);
      throw StateError('Authenticated user is required.');
    }

    return user.uid;
  }

  @override
  void onInit() {
    super.onInit();
    _bindWallet();
  }

  void _bindWallet() {
    _summarySub = _walletRepository
        .watchWalletSummary(userId)
        .listen(
          (summary) {
            balance.value = summary.balance;
            availableBalance.value = summary.availableBalance;
            pendingWithdrawal.value = summary.pendingWithdrawal;
            points.value = summary.points;
            isLoading.value = false;
          },
          onError: (_) {
            isLoading.value = false;
            errorMessage.value = 'Không tải được số dư ví.';
          },
        );

    _transactionsSub = _walletRepository
        .watchWalletTransactions(userId)
        .listen(
          (items) {
            transactions.assignAll(items);
          },
          onError: (_) {
            errorMessage.value = 'Không tải được lịch sử giao dịch.';
          },
        );
  }

  String formatMoney(num value) => CurrencyFormat.vnd(value);

  String formatPoints(int value) => CurrencyFormat.number(value);

  String formatTransactionAmount(WalletTransactionModel transaction) {
    final prefix = transaction.isCredit ? '+' : '-';
    return '$prefix${formatMoney(transaction.amount.abs())}';
  }

  String formatDate(DateTime? date) =>
      DateFormatUtils.nullableDayMonthYear(date);

  void goBack() {
    Get.back<void>();
  }

  void resetWithdrawForm() {
    selectedWithdrawBank.value = null;
    withdrawAmountController.clear();
    withdrawAccountController.clear();
    withdrawNameController.clear();
    isWithdrawing.value = false;
  }

  void openWithdrawSheet(Widget sheet) {
    resetWithdrawForm();
    Get.bottomSheet<void>(
      sheet,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ).whenComplete(resetWithdrawForm);
  }

  void closeWithdrawSheet() {
    if (Get.isBottomSheetOpen == true) {
      Get.back<void>();
    }
  }

  Future<void> submitWithdrawFromSheet() async {
    final success = await submitWithdraw();
    if (success) {
      closeWithdrawSheet();
    }
  }

  Future<bool> submitWithdraw() async {
    if (isWithdrawing.value) return false;

    final bankName = selectedWithdrawBank.value;
    final amount = double.tryParse(withdrawAmountController.text.trim());
    final accountNumber = withdrawAccountController.text.trim();
    final accountName = withdrawNameController.text.trim();

    if (bankName == null ||
        bankName.isEmpty ||
        amount == null ||
        accountNumber.isEmpty ||
        accountName.isEmpty) {
      Get.snackbar(
        'Thiếu thông tin',
        'Vui lòng điền đầy đủ thông tin rút tiền.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (amount <= 0) {
      Get.snackbar(
        'Số tiền không hợp lệ',
        'Số tiền rút phải lớn hơn 0.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (amount > availableBalance.value) {
      Get.snackbar(
        'Số dư không đủ',
        'Số tiền rút vượt quá số dư ví hiện tại.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    isWithdrawing.value = true;
    try {
      final result = await _walletRepository.withdraw(
        amount: amount,
        bankName: bankName,
        bankAccountNumber: accountNumber,
        bankAccountName: accountName,
      );
      balance.value = result.newBalance;
      availableBalance.value = result.availableBalance;
      pendingWithdrawal.value = result.pendingWithdrawal;
      await refreshTransactions();
      Get.snackbar(
        'Đã gửi yêu cầu',
        'Yêu cầu rút tiền đã được tạo.',
        snackPosition: SnackPosition.BOTTOM,
      );
      resetWithdrawForm();
      return true;
    } on WalletApiException catch (error) {
      Get.snackbar(
        'Không thể rút tiền',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Không thể rút tiền',
        'Vui lòng thử lại sau.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isWithdrawing.value = false;
    }

    return false;
  }

  Future<void> refreshTransactions() async {
    try {
      final items = await _walletRepository.fetchWalletTransactions();
      transactions.assignAll(items);
    } catch (_) {
      errorMessage.value = 'KhÃ´ng táº£i Ä‘Æ°á»£c lá»‹ch sá»­ giao dá»‹ch.';
    }
  }

  @override
  void onClose() {
    _summarySub?.cancel();
    _transactionsSub?.cancel();
    withdrawAmountController.dispose();
    withdrawAccountController.dispose();
    withdrawNameController.dispose();
    super.onClose();
  }
}
