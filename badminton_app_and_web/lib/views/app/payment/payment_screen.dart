import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../widgets/custom_button.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String courtName;
  final double price;
  final String date;
  final String time;
  final bool isFixed;
  final String? fixedDuration; // E.g., "1 tháng", "3 tháng"

  const PaymentScreen({
    super.key,
    required this.courtName,
    required this.price,
    required this.date,
    required this.time,
    required this.isFixed,
    this.fixedDuration,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Timer _countdownTimer;
  int _startSeconds = 598; // 09:58
  final String _bankName = 'Vietcombank';
  final String _bankAccountNo = '1029384756';
  final String _accountHolder = 'CONG TY SHUTTLEGO VINA';
  late String _transferContent;

  @override
  void initState() {
    super.initState();
    // Generate a unique booking transaction content
    final randomNum = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _transferContent = 'BOOKING$randomNum';
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds == 0) {
        setState(() {
          _countdownTimer.cancel();
        });
        _showTimeoutDialog();
      } else {
        setState(() {
          _startSeconds--;
        });
      }
    });
  }

  String _getFormattedTime() {
    final minutes = (_startSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_startSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hết thời gian giữ chỗ', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Phiên thanh toán đã hết hạn. Vui lòng thực hiện đặt sân lại từ đầu.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Get.back();
            },
            child: const Text('Đồng ý', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Thành công',
      'Đã sao chép $label vào bộ nhớ tạm',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  String _formatMoney(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 16),
          ),
        ),
        title: const Text(
          'Thanh toán',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Timer box
                    _buildCountdownTimer(),
                    const SizedBox(height: 20),

                    // Payment details container
                    _buildPaymentCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFFF9800), size: 16),
          const SizedBox(width: 6),
          Text(
            'Giữ chỗ trong: ${_getFormattedTime()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF9800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Court details
          Text(
            widget.courtName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatMoney(widget.price),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 22),

          // QR Code Graphic
          _buildQrCodeGraphics(),
          const SizedBox(height: 12),
          const Text(
            'SCAN TO PAY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.grey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Transfer content card
          _buildInfoRow(
            label: 'NỘI DUNG CHUYỂN KHOẢN',
            value: _transferContent,
            onCopy: () => _copyToClipboard(_transferContent, 'nội dung chuyển khoản'),
          ),
          const SizedBox(height: 14),

          // Bank details card
          _buildInfoRow(
            label: 'NGÂN HÀNG',
            value: _bankName,
            subValue: 'STK: $_bankAccountNo\nChủ TK: $_accountHolder',
            onCopy: () => _copyToClipboard(_bankAccountNo, 'số tài khoản'),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeGraphics() {
    return Container(
      width: 180,
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: CustomPaint(
        size: const Size(156, 156),
        painter: QrCodeMockPainter(primaryColor: AppColors.black),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    String? subValue,
    required VoidCallback onCopy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                if (subValue != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subValue,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.copy_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: CustomButton(
        text: 'Đã thanh toán',
        onTap: () {
          _countdownTimer.cancel();
          Get.to(() => PaymentSuccessScreen(
                courtName: widget.courtName,
                price: widget.price,
                date: widget.date,
                time: widget.time,
                bookingCode: _transferContent,
              ));
        },
      ),
    );
  }
}

class QrCodeMockPainter extends CustomPainter {
  final Color primaryColor;

  QrCodeMockPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    const finderSize = 36.0;
    const innerSize = 20.0;
    const centerSize = 8.0;

    // Helper to draw a finder pattern at (x, y)
    void drawFinder(double x, double y) {
      // Outer square
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, finderSize, finderSize),
          const Radius.circular(6),
        ),
        paint,
      );
      // White inner mask
      paint.color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(x + 5, y + 5, finderSize - 10, finderSize - 10),
        paint,
      );
      // Center solid square
      paint.color = primaryColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + (finderSize - centerSize * 2) / 2,
            y + (finderSize - centerSize * 2) / 2,
            centerSize * 2,
            centerSize * 2,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }

    // Top-Left Finder
    drawFinder(0, 0);

    // Top-Right Finder
    drawFinder(size.width - finderSize, 0);

    // Bottom-Left Finder
    drawFinder(0, size.height - finderSize);

    // Bottom-Right small alignment pattern (standard QR code)
    const alignSize = 14.0;
    final ax = size.width - finderSize;
    final ay = size.height - finderSize;
    canvas.drawRect(Rect.fromLTWH(ax + 10, ay + 10, alignSize, alignSize), paint);
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(ax + 13, ay + 13, alignSize - 6, alignSize - 6), paint);
    paint.color = primaryColor;
    canvas.drawRect(Rect.fromLTWH(ax + 15, ay + 15, alignSize - 10, alignSize - 10), paint);

    // Draw some random pseudo-random grid data in between to make it look like a QR code
    final randomDataGrid = [
      [1,0,1,1,0,1,1,0,0,1,0,1,1,0,1,1],
      [0,1,0,0,1,0,0,1,1,0,1,0,0,1,0,0],
      [1,1,0,1,1,0,1,0,0,1,1,0,1,0,1,1],
      [0,0,1,0,0,1,1,0,1,0,0,1,0,1,0,0],
      [1,0,1,1,0,0,0,1,0,1,1,0,0,0,1,1],
      [0,1,0,0,1,1,0,1,1,0,0,1,1,0,0,0],
      [1,1,0,1,0,0,1,0,0,1,0,0,0,1,1,0],
      [0,0,1,0,1,1,0,1,0,0,1,1,0,1,0,1],
      [0,1,1,0,0,0,1,1,0,1,1,0,0,0,1,1],
      [1,0,0,1,1,0,1,0,1,0,0,1,1,0,1,0],
      [0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1],
      [1,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0],
      [0,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1],
      [1,0,1,1,0,1,0,0,1,0,1,0,1,0,1,0],
      [0,1,0,0,1,0,1,1,0,1,0,1,0,1,0,1],
      [1,1,1,0,0,1,0,0,1,1,0,0,1,1,0,0]
    ];

    final cellSize = size.width / 16;
    for (int r = 0; r < 16; r++) {
      for (int c = 0; c < 16; c++) {
        // Skip finder areas
        if (r < 4 && c < 4) continue; // Top-Left Finder
        if (r < 4 && c >= 12) continue; // Top-Right Finder
        if (r >= 12 && c < 4) continue; // Bottom-Left Finder
        if (r >= 12 && c >= 12) continue; // Bottom-Right alignment area

        if (randomDataGrid[r][c] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize - 0.5, cellSize - 0.5),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
