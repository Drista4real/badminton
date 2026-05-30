// ===============================
// FILE: lib/views/app/history/history_screen.dart
// ===============================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../booking/booking_screen.dart';
import '../home/home_screen.dart';
import '../notification/notification_screen.dart';
import '../wallet/wallet_screen.dart';
import '../payment/payment_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int initialIndex; // 0: Sân lẻ, 1: Cố định

  const HistoryScreen({super.key, this.initialIndex = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _selectedNavIndex = 4; // Highlight Profile/History tab

  // Dummy Single Bookings (Sân lẻ)
  final List<Map<String, dynamic>> _singleBookings = [
    {
      'court': 'Sân Cầu Lông 01',
      'date': '20/10/2023',
      'time': '18:00 - 20:00',
      'price': 120000.0,
      'status': 'HOÀN THÀNH',
      'statusColor': const Color(0xFF4CAF50),
      'statusBg': const Color(0xFFE8F5E9),
    },
    {
      'court': 'Sân Cầu Lông 02',
      'date': '18/10/2023',
      'time': '19:00 - 21:00',
      'price': 150000.0,
      'status': 'ĐÃ HỦY',
      'statusColor': const Color(0xFFEF5350),
      'statusBg': const Color(0xFFFFEBEE),
    },
    {
      'court': 'Sân Cầu Lông 01',
      'date': '25/10/2023',
      'time': '17:00 - 19:00',
      'price': 140000.0,
      'status': 'CHỜ CỌC',
      'statusColor': const Color(0xFFFF9800),
      'statusBg': const Color(0xFFFFF3E0),
    },
  ];

  // Dummy Fixed Bookings (Cố định)
  final List<Map<String, dynamic>> _fixedBookings = [
    {
      'id': 'FIXED_01',
      'court': 'Sân Cầu Lông 01',
      'days': 'Thứ 3, Thứ 5 hàng tuần',
      'time': '18:00 - 20:00',
      'duration': 'Thời hạn: 1 tháng',
      'months': 1,
      'price': 1600000.0, // 8 sessions * 200k/session
    },
    {
      'id': 'FIXED_02',
      'court': 'Sân Cầu Lông 02',
      'days': 'Thứ 7, Chủ Nhật hàng tuần',
      'time': '08:00 - 10:00',
      'duration': 'Thời hạn: 3 tháng',
      'months': 3,
      'price': 4800000.0, // 24 sessions * 200k/session
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatMoney(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
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
          'Lịch sử đặt sân',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom TabBar
            _buildTabBar(),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSingleBookingsList(),
                  _buildFixedBookingsList(),
                ],
              ),
            ),

            // Bottom Nav Bar
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Sân lẻ'),
            Tab(text: 'Cố định'),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleBookingsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _singleBookings.length,
      itemBuilder: (context, index) {
        final booking = _singleBookings[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual court graphic representation instead of raw image path failures
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B7D77), Color(0xFF12B3A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_tennis_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          booking['court'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: booking['statusBg'],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            booking['status'],
                            style: TextStyle(
                              color: booking['statusColor'],
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildIconLabelRow(Icons.calendar_today_rounded, 'Ngày: ${booking['date']}'),
                    const SizedBox(height: 5),
                    _buildIconLabelRow(Icons.access_time_rounded, 'Giờ: ${booking['time']}'),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Giá: ',
                            style: TextStyle(fontSize: 12, color: AppColors.grey, fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: _formatMoney(booking['price']),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFixedBookingsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _fixedBookings.length,
      itemBuilder: (context, index) {
        final booking = _fixedBookings[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['court'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Đã đăng ký cố định',
                          style: TextStyle(fontSize: 11, color: AppColors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildIconLabelRow(Icons.calendar_today_rounded, booking['days']),
              const SizedBox(height: 8),
              _buildIconLabelRow(Icons.access_time_rounded, booking['time']),
              const SizedBox(height: 8),
              _buildIconLabelRow(Icons.timelapse_rounded, booking['duration']),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _showCancelSessionSheet(booking),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade400, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'Báo nghỉ buổi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => _showRenewContractSheet(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Gia hạn',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconLabelRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.grey,
          ),
        ),
      ],
    );
  }

  // Interactive Absense Reporter sheet
  void _showCancelSessionSheet(Map<String, dynamic> booking) {
    final List<String> dummySessions = [
      'Buổi 1: Thứ Ba, 02/06 (18:00 - 20:00)',
      'Buổi 2: Thứ Năm, 04/06 (18:00 - 20:00)',
      'Buổi 3: Thứ Ba, 09/06 (18:00 - 20:00)',
      'Buổi 4: Thứ Năm, 11/06 (18:00 - 20:00)',
    ];
    int? selectedSessionIdx;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Báo nghỉ buổi cố định',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.black),
              ),
              const SizedBox(height: 6),
              const Text(
                'Số tiền hoàn lại 75% giá trị buổi tập sẽ được chuyển vào ví tài khoản của bạn.',
                style: TextStyle(fontSize: 11, color: AppColors.grey),
              ),
              const SizedBox(height: 16),
              ...List.generate(dummySessions.length, (idx) {
                final isSelected = selectedSessionIdx == idx;
                return GestureDetector(
                  onTap: () => setS(() => selectedSessionIdx = idx),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.04) : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFEEEEEE),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? AppColors.primary : AppColors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dummySessions[idx],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Xác nhận báo nghỉ',
                onTap: () {
                  if (selectedSessionIdx == null) {
                    Get.snackbar(
                      'Thông báo',
                      'Vui lòng chọn buổi muốn nghỉ!',
                      backgroundColor: Colors.orange,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  Get.snackbar(
                    'Báo nghỉ thành công',
                    'Đã hủy buổi tập cố định. Hoàn tiền 75% thành công vào ví!',
                    backgroundColor: AppColors.primary,
                    colorText: Colors.white,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Interactive contract renewal sheet
  void _showRenewContractSheet(Map<String, dynamic> booking) {
    int durationMonths = 1;
    final basePrice = booking['price'] as double;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final totalPrice = basePrice * durationMonths;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gia hạn: ${booking['court']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.black),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn thời gian gia hạn thêm',
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [1, 3, 6].map((m) {
                    final isSelected = durationMonths == m;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => durationMonths = m),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFFEEEEEE),
                            ),
                          ),
                          child: Text(
                            '$m tháng',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppColors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng tiền thanh toán',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.black),
                    ),
                    Text(
                      _formatMoney(totalPrice),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Tiến hành thanh toán',
                  onTap: () {
                    Navigator.pop(ctx);
                    // Navigate to QR payment screen with renewal details
                    Get.to(() => PaymentScreen(
                          courtName: '${booking['court']} (Gia hạn)',
                          price: totalPrice,
                          date: 'Gia hạn từ ngày tiếp theo',
                          time: booking['time'],
                          isFixed: true,
                          fixedDuration: '$durationMonths tháng',
                        ));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Trang chủ'},
      {'icon': Icons.sports_tennis_rounded, 'label': 'Đặt sân'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Ví'},
      {'icon': Icons.notifications_rounded, 'label': 'Thông báo'},
      {'icon': Icons.person_rounded, 'label': 'Hồ sơ'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isSelected = _selectedNavIndex == i;
              return GestureDetector(
                onTap: () {
                  if (i == 0) {
                    Get.offAll(() => const HomeScreen());
                  } else if (i == 1) {
                    Get.off(() => const BookingScreen());
                  } else if (i == 2) {
                    Get.off(() => const WalletScreen());
                  } else if (i == 3) {
                    Get.off(() => const NotificationScreen());
                  }
                  // Clicking 4 does nothing since we are already on history/profile screen
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i]['icon'] as IconData,
                        color: isSelected ? AppColors.primary : AppColors.grey,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? AppColors.primary : AppColors.grey,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
