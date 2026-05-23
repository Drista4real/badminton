// ===============================
// FILE: lib/views/app/notification/notification_screen.dart
// ===============================

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Tất cả', 'Đặt sân', 'Thanh toán', 'Hệ thống'];

  final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'booking',
      'title': 'Đặt sân thành công',
      'message': 'Sân 2 đã được đặt cho khung giờ 18:00 - 20:00.',
      'time': '2 phút trước',
      'isRead': false,
      'icon': Icons.sports_tennis_rounded,
      'color': Color(0xFF0B7D77),
    },
    {
      'type': 'payment',
      'title': 'Thanh toán thành công',
      'message': 'Đã nhận 200.000VND vào tài khoản.',
      'time': '1 giờ trước',
      'isRead': false,
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'type': 'system',
      'title': 'Cập nhật hệ thống',
      'message': 'Nhiều tính năng mới đã được cập nhật. Khám phá ngay!',
      'time': 'Hôm qua',
      'isRead': true,
      'icon': Icons.system_update_rounded,
      'color': Color(0xFF9E9E9E),
    },
    {
      'type': 'booking',
      'title': 'Đã huỷ đặt sân',
      'message': 'Yêu cầu đặt Sân 5 của bạn đã được huỷ.',
      'time': '2 ngày trước',
      'isRead': true,
      'icon': Icons.cancel_rounded,
      'color': Color(0xFFEF5350),
    },
    {
      'type': 'payment',
      'title': 'Nhắc nhở thanh toán',
      'message': 'Bạn có lịch cố định sắp đến hạn thanh toán vào ngày 01/06.',
      'time': '3 ngày trước',
      'isRead': true,
      'icon': Icons.notifications_active_rounded,
      'color': Color(0xFFFF9800),
    },
    {
      'type': 'booking',
      'title': 'Xác nhận lịch cố định',
      'message': 'Lịch cố định Sân 3 - T3, T5 từ 18:00-20:00 đã được xác nhận.',
      'time': '5 ngày trước',
      'isRead': true,
      'icon': Icons.event_available_rounded,
      'color': Color(0xFF0B7D77),
    },
    {
      'type': 'system',
      'title': 'Chào mừng bạn!',
      'message': 'Cảm ơn bạn đã đăng ký ShuttleGo. Đặt sân ngay hôm nay!',
      'time': '1 tuần trước',
      'isRead': true,
      'icon': Icons.celebration_rounded,
      'color': Color(0xFF9C27B0),
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedTab == 0) return _notifications;
    final types = ['', 'booking', 'payment', 'system'];
    return _notifications.where((n) => n['type'] == types[_selectedTab]).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n['isRead']).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primary, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Thông báo',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          ),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: () => setState(() {
                for (var n in _notifications) n['isRead'] = true;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Đọc tất cả',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final isSelected = _selectedTab == i;
            final count = i == 0
                ? _unreadCount
                : _notifications
                    .where((n) =>
                        n['type'] == ['', 'booking', 'payment', 'system'][i] &&
                        !n['isRead'])
                    .length;

            return GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _tabs[i],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.grey),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? AppColors.primary : Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Không có thông báo',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + 1,
      itemBuilder: (_, i) {
        if (i == items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Bạn đã xem hết thông báo hôm nay!',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ),
          );
        }
        return _buildNotificationCard(items[i], i);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item, int index) {
    final isRead = item['isRead'] as bool;
    final color = item['color'] as Color;

    return GestureDetector(
      onTap: () {
        setState(() {
          final idx = _notifications.indexOf(item);
          if (idx != -1) _notifications[idx]['isRead'] = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? Colors.grey.shade100 : color.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['title'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item['time'],
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['message'],
                      style: TextStyle(
                          fontSize: 12,
                          color: isRead ? AppColors.grey : AppColors.black,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              // Unread dot
              if (!isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 2),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}