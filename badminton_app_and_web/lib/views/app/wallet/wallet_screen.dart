import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../controllers/app/wallet_controller.dart';
import '../../../data/models/wallet_transaction_model.dart';
import '../../../commons/widgets/custom_button.dart';

class WalletScreen extends GetView<WalletController> {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const _WalletHeader(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.refreshWallet,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        if (controller.errorMessage.value.isNotEmpty)
                          _ErrorBanner(message: controller.errorMessage.value),
                        const _BalanceCard(),
                        const SizedBox(height: 16),
                        const _PointsCard(),
                        const SizedBox(height: 16),
                        const _TransactionList(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletHeader extends GetView<WalletController> {
  const _WalletHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: controller.goBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'wallet.title'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          GestureDetector(
            onTap: controller.refreshWallet,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFF9800),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BalanceCard extends GetView<WalletController> {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7D77), Color(0xFF0DBDB6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SỐ DƯ VÍ TIỀN',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Text(
                controller.formatMoney(controller.balance.value),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tiền hoàn từ các đơn hủy hoặc thanh toán trễ',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
            const SizedBox(height: 18),
            Obx(
              () => GestureDetector(
                onTap: controller.canRequestWithdraw
                    ? () => controller.openWithdrawSheet(const _WithdrawSheet())
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Yêu cầu rút tiền',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsCard extends GetView<WalletController> {
  const _PointsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: Color(0xFFFF9800),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ĐIỂM TÍCH LŨY',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Obx(
                        () => Text(
                          controller.formatPoints(controller.points.value),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text(
                          'Điểm',
                          style: TextStyle(fontSize: 13, color: AppColors.grey),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Dùng điểm tích lũy để giảm giá khi thanh toán',
                    style: TextStyle(fontSize: 10, color: AppColors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Đổi điểm',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFF9800),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends GetView<WalletController> {
  const _TransactionList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Lịch sử giao dịch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              Text(
                'Realtime',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.transactions.isEmpty) {
              return const _EmptyTransactions();
            }

            return Column(
              children: controller.transactions
                  .map((transaction) => _TransactionItem(transaction))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Chưa có giao dịch ví.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.grey),
      ),
    );
  }
}

class _TransactionItem extends GetView<WalletController> {
  const _TransactionItem(this.transaction);

  final WalletTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: transaction.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.icon,
              color: transaction.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  controller.formatDate(transaction.createdAt),
                  style: const TextStyle(fontSize: 10, color: AppColors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                controller.formatTransactionAmount(transaction),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: transaction.isCredit
                      ? const Color(0xFF4CAF50)
                      : AppColors.black,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: transaction.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  transaction.statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    color: transaction.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheet extends GetView<WalletController> {
  const _WithdrawSheet();

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        final mediaQuery = MediaQuery.of(ctx);
        final availableHeight =
            mediaQuery.size.height - mediaQuery.viewInsets.bottom;
        final sheetHeight = availableHeight * 0.86;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: controller.closeWithdrawSheet,
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Nhận tiền hoàn trả',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Thông tin này dùng khi bạn muốn rút số dư ví về tài khoản ngân hàng.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.grey,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Thông tin nhận tiền',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const _RefundLabel('Số tiền rút *'),
                                const SizedBox(height: 6),
                                _RefundTextField(
                                  controller:
                                      controller.withdrawAmountController,
                                  hintText: 'Nhập số tiền muốn rút',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  suffixIcon: const Icon(
                                    Icons.payments_rounded,
                                    color: AppColors.grey,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _RefundLabel('Tên ngân hàng *'),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: DropdownButton<String>(
                                    value:
                                        controller.selectedWithdrawBank.value,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    hint: const Text(
                                      'Chọn ngân hàng',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.primary,
                                    ),
                                    items: controller.withdrawBanks
                                        .map(
                                          (bank) => DropdownMenuItem(
                                            value: bank,
                                            child: Text(bank),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        controller.selectedWithdrawBank.value =
                                            value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _RefundLabel('Số tài khoản *'),
                                const SizedBox(height: 6),
                                _RefundTextField(
                                  controller:
                                      controller.withdrawAccountController,
                                  hintText: 'Nhập số tài khoản của bạn',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  suffixIcon: const Icon(
                                    Icons.credit_card_rounded,
                                    color: AppColors.grey,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _RefundLabel('Tên chủ thẻ *'),
                                const SizedBox(height: 6),
                                _RefundTextField(
                                  controller: controller.withdrawNameController,
                                  hintText: 'NHẬP TÊN CHỦ THẺ KHÔNG DẤU',
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 12,
                                      color: AppColors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Giao dịch bảo mật 256-bit',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Obx(
                            () => CustomButton(
                              text: 'Xác nhận rút tiền',
                              isLoading: controller.isWithdrawing.value,
                              onTap: controller.submitWithdrawFromSheet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RefundLabel extends StatelessWidget {
  const _RefundLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      ),
    );
  }
}

class _RefundTextField extends StatelessWidget {
  const _RefundTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
