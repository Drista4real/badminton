import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../controllers/app/payment_controller.dart';
import '../../../utils/currency_format.dart';

class PaymentScreen extends StatefulWidget {
  final String courtName;
  final double price;
  final String date;
  final String time;
  final bool isFixed;
  final String? fixedDuration;
  final String? orderId;
  final List<String> bookingIds;

  const PaymentScreen({
    super.key,
    required this.courtName,
    required this.price,
    required this.date,
    required this.time,
    required this.isFixed,
    this.fixedDuration,
    this.orderId,
    this.bookingIds = const <String>[],
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final String _orderId;
  late final PaymentController _controller;
  bool _isExitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    final orderId = widget.orderId?.trim();
    _controller = Get.find<PaymentController>();

    if (orderId == null || orderId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          'Không thể thanh toán',
          'Thiếu mã đơn hàng thanh toán.',
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.back<void>();
      });
      _orderId = '';
      return;
    }

    _orderId = orderId;
    _controller.startPayment(
      orderId: _orderId,
      amount: widget.price,
      courtName: widget.courtName,
      date: widget.date,
      time: widget.time,
      isFixed: widget.isFixed,
      fixedDuration: widget.fixedDuration,
      bookingIds: widget.bookingIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmExitPayment();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: GestureDetector(
            onTap: _confirmExitPayment,
            child: Container(
              margin: const EdgeInsets.all(10),
              alignment: Alignment.center,
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
          title: const Text(
            'Thanh toán',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCountdownTimer(),
                const SizedBox(height: 20),
                _buildPaymentCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownTimer() {
    return Obx(
      () {
        if (!_controller.isPaymentPrepared.value ||
            _controller.qrUrl.value.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer_outlined,
              color: Color(0xFFFF9800),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Giữ chỗ trong: ${_controller.formattedCountdown}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        );
      },
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.courtName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormat.vnd(widget.price),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 22),
          _buildBenefitOptions(),
          const SizedBox(height: 14),
          _buildPaymentSummary(),
          const SizedBox(height: 18),
          Obx(() {
            if (!_controller.isPaymentPrepared.value) {
              return _buildPreparePaymentState();
            }

            return _buildQrState();
          }),
          const SizedBox(height: 18),
          _buildOrderCode(),
        ],
      ),
    );
  }

  Widget _buildBenefitOptions() {
    return Obx(
      () => Column(
        children: [
          _BenefitCheckbox(
            value: _controller.useWallet.value,
            enabled: _controller.canChangeBenefitOptions,
            title: 'Dùng Ví tiền',
            subtitle: 'Số dư khả dụng: ${_controller.formattedWalletBalance}',
            onChanged: _controller.toggleUseWallet,
          ),
          const SizedBox(height: 8),
          _BenefitCheckbox(
            value: _controller.useRewardPoints.value,
            enabled: _controller.canChangeBenefitOptions,
            title: 'Dùng điểm tích lũy',
            subtitle:
                '${_controller.formattedRewardPoints} điểm - tối thiểu 100 điểm, 1 điểm = 200 VNĐ',
            onChanged: _controller.toggleUseRewardPoints,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Obx(
      () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Tạm tính',
              value: _controller.formattedOriginalAmount,
            ),
            if (_controller.walletDiscount.value > 0) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Trừ ví tiền',
                value: '-${_controller.formattedWalletDiscount}',
                valueColor: const Color(0xFF2E7D32),
              ),
            ],
            if (_controller.pointDiscount.value > 0) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Trừ điểm (${_controller.pointsSpent.value} điểm)',
                value: '-${_controller.formattedPointDiscount}',
                valueColor: const Color(0xFF2E7D32),
              ),
            ],
            const Divider(height: 22),
            _SummaryRow(
              label: 'Cần thanh toán VietQR',
              value: _controller.formattedPayableAmount,
              valueColor: AppColors.primary,
              isEmphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreparePaymentState() {
    if (_controller.isLoading.value) {
      return const SizedBox(
        width: double.infinity,
        height: 52,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Column(
      children: [
        if (_controller.errorMessage.value.isNotEmpty) ...[
          Text(
            _controller.errorMessage.value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFFEF5350)),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _controller.preparePayment,
            icon: const Icon(Icons.qr_code_rounded, size: 18),
            label: const Text(
              'Xác nhận và tạo mã VietQR',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrState() {
    if (_controller.isLoading.value) {
      return const SizedBox(
        width: 190,
        height: 190,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_controller.errorMessage.value.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF5350),
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              _controller.errorMessage.value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.grey),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _controller.retryGenerateQr,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    if (_controller.qrUrl.value.isEmpty) {
      return const SizedBox(
        width: 190,
        height: 190,
        child: Center(
          child: Text(
            'Đang chuẩn bị mã QR...',
            style: TextStyle(fontSize: 13, color: AppColors.grey),
          ),
        ),
      );
    }

    return Container(
      width: 210,
      height: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _buildQrImage(_controller.qrUrl.value),
    );
  }

  Widget _buildQrImage(String qrSource) {
    final imageBytes = _decodeDataUriImage(qrSource);
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildQrImageError(),
      );
    }

    return Image.network(
      qrSource,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildQrImageError(),
    );
  }

  Uint8List? _decodeDataUriImage(String source) {
    final value = source.trim();
    if (!value.startsWith('data:image')) return null;

    const marker = 'base64,';
    final markerIndex = value.indexOf(marker);
    if (markerIndex < 0) return null;

    try {
      return base64Decode(value.substring(markerIndex + marker.length));
    } on FormatException {
      return null;
    }
  }

  Widget _buildQrImageError() {
    return const Center(
      child: Text(
        'Không tải được ảnh QR.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.grey),
      ),
    );
  }

  Widget _buildOrderCode() {
    return Obx(
      () => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MA DON HANG',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _controller.paymentContent.value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExitPayment() async {
    if (_isExitDialogOpen || _controller.isCancelling.value || !mounted) {
      return;
    }

    _isExitDialogOpen = true;
    try {
      final shouldExit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Bạn có chắc muốn thoát?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'Đơn hàng sẽ bị hủy nếu không thanh toán',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Ở lại'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Thoát'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (shouldExit == true) {
        await _controller.cancelPaymentAndGoHome();
      }
    } finally {
      _isExitDialogOpen = false;
    }
  }
}

class _BenefitCheckbox extends StatelessWidget {
  const _BenefitCheckbox({
    required this.value,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final String title;
  final String subtitle;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.07)
            : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.4)
              : const Color(0xFFEEEEEE),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.grey),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.black,
    this.isEmphasized = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isEmphasized ? 13 : 12,
              color: AppColors.grey,
              fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isEmphasized ? 16 : 13,
            color: valueColor,
            fontWeight: isEmphasized ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
