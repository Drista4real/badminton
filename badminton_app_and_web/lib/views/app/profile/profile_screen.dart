// ===============================
// FILE: lib/views/app/profile/profile_screen.dart
// ===============================

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../home/home_screen.dart';
import '../booking/booking_screen.dart';
import '../wallet/wallet_screen.dart';
import '../notification/notification_screen.dart';
import '../history/history_screen.dart';
import 'change_password_screen.dart';
import 'review_screen.dart';
import 'map_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedNavIndex = 4;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildPersonalInfo(),
                    const SizedBox(height: 12),
                    _buildActivities(),
                    const SizedBox(height: 12),
                    _buildPreferences(),
                    const SizedBox(height: 12),
                    _buildSecurity(),
                    const SizedBox(height: 12),
                    _buildLogout(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 44),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Nguyễn Đức Tính',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'nductinh101@gmail.com',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return _buildSection(
      title: 'THÔNG TIN CÁ NHÂN',
      children: [
        _buildEditableRow(Icons.person_outline_rounded, 'Họ và tên', 'Nguyễn Đức Tính'),
        _buildDivider(),
        _buildEditableRow(Icons.phone_outlined, 'Số điện thoại', '0355342723'),
        _buildDivider(),
        _buildEditableRow(Icons.email_outlined, 'Địa chỉ email', 'nductinh101@gmail.com'),
      ],
    );
  }

  Widget _buildActivities() {
    return _buildSection(
      title: 'HOẠT ĐỘNG CỦA TÔI',
      children: [
        _buildNavRow(
          Icons.history_rounded,
          'Lịch sử đặt sân',
          onTap: () => Get.to(() => const HistoryScreen()),
        ),
        _buildDivider(),
        _buildNavRow(
          Icons.star_outline_rounded,
          'Đánh giá',
          onTap: () => Get.to(() => const ReviewScreen()),
        ),
        _buildDivider(),
        _buildNavRow(
          Icons.location_on_outlined,
          'Vị trí sân',
          onTap: () => Get.to(() => const MapScreen()),
        ),
      ],
    );
  }

  Widget _buildPreferences() {
    return _buildSection(
      title: 'SỞ THÍCH',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dark_mode_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Chế độ tối',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: _darkMode,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _darkMode = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurity() {
    return _buildSection(
      title: 'BẢO VỆ',
      children: [
        _buildNavRow(
          Icons.lock_outline_rounded,
          'Thay đổi mật khẩu',
          onTap: () => Get.to(() => const ChangePasswordScreen()),
        ),
      ],
    );
  }

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _showLogoutDialog,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
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
          child: const Text(
            'Đăng xuất',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEF5350),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
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
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
        ],
      ),
    );
  }

  Widget _buildNavRow(IconData icon, String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 66, endIndent: 16, color: Color(0xFFF0F0F0));
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.black),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
          style: TextStyle(color: AppColors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Get.snackbar(
                'Đã đăng xuất',
                'Hẹn gặp lại bạn!',
                backgroundColor: AppColors.primary,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                  if (i == 0) Get.offAll(() => const HomeScreen());
                  else if (i == 1) Get.off(() => const BookingScreen());
                  else if (i == 2) Get.off(() => const WalletScreen());
                  else if (i == 3) Get.off(() => const NotificationScreen());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
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
