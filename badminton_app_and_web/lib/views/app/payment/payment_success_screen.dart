
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../home/home_screen.dart';
import '../history/history_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String courtName;
  final double price;
  final String date;
  final String time;
  final String bookingCode;

  const PaymentSuccessScreen({
    super.key,
    required this.courtName,
    required this.price,
    required this.date,
    required this.time,
    required this.bookingCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success graphic
              _buildSuccessGraphic(),
              const SizedBox(height: 28),

              // Success text
              const Text(
                'Đặt sân thành công!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 32),

              // Details card
              _buildReceiptCard(),

              const Spacer(flex: 2),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessGraphic() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Decorative background elements
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              width: 1.5,
              style: BorderStyle.solid, // Simulated dashed border or light border box
            ),
          ),
        ),
        // Success circle
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x3D12B3A8),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon badminton
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FAF9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sports_tennis_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Court & Booking ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courtName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'MÃ ĐẶT CHỖ: #$bookingCode',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Dashed Divider line
          Row(
            children: List.generate(
              30,
              (index) => Expanded(
                child: Container(
                  height: 1,
                  color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          // Body info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildReceiptRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Ngày',
                  value: date,
                ),
                const SizedBox(height: 12),
                _buildReceiptRow(
                  icon: Icons.access_time_rounded,
                  label: 'Thời gian',
                  value: time,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        CustomButton(
          text: 'Về Trang Chủ',
          onTap: () {
            // Clear route stack and go to home screen
            Get.offAll(() => const HomeScreen());
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton(
            onPressed: () {
              // Open History Screen directly
              Get.offAll(() => const HomeScreen()); // Ensure home stack exists
              Get.to(() => const HistoryScreen(initialIndex: 0));
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Xem Đơn Hàng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
