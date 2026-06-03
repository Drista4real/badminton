import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commons/styles/app_colors.dart';
import '../../data/models/notification_model.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/notification_repository.dart';
import '../../routes/app_routes.dart';

class NotificationController extends GetxController {
  NotificationController({
    required NotificationRepository notificationRepository,
    required AuthRepository authRepository,
  }) : _notificationRepository = notificationRepository,
       _authRepository = authRepository;

  final NotificationRepository _notificationRepository;
  final AuthRepository _authRepository;

  final selectedTab = 0.obs;
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final notifications = <NotificationModel>[].obs;

  StreamSubscription<List<NotificationModel>>? _notificationsSub;

  static const tabKeys = [
    'history.tab.all',
    'notification.tab.booking',
    'notification.tab.payment',
    'notification.tab.system',
  ];
  static List<String> get tabs =>
      tabKeys.map((key) => key.tr).toList(growable: false);
  static const _tabTypes = ['', 'booking', 'payment', 'system'];

  String get userId {
    final user = _authRepository.currentUser;
    if (user == null || user.uid.isEmpty || user.isAnonymous) {
      Get.offAllNamed(AppRoutes.login);
      throw StateError('Authenticated user is required.');
    }

    return user.uid;
  }

  int get unreadCount {
    return notifications.where((item) => !item.isRead).length;
  }

  List<NotificationModel> get filteredNotifications {
    if (selectedTab.value == 0) {
      return notifications.toList();
    }

    final type = _tabTypes[selectedTab.value];
    return notifications.where((item) => item.type == type).toList();
  }

  @override
  void onInit() {
    super.onInit();
    _watchNotifications();
  }

  void selectTab(int index) {
    selectedTab.value = index;
  }

  int unreadCountForTab(int index) {
    if (index == 0) {
      return unreadCount;
    }

    final type = _tabTypes[index];
    return notifications
        .where((item) => item.type == type && !item.isRead)
        .length;
  }

  Future<void> markAsRead(NotificationModel item) async {
    if (item.isRead) {
      return;
    }

    await _notificationRepository.markAsRead(item.id);
  }

  Future<void> markAllAsRead() async {
    if (unreadCount == 0) {
      return;
    }

    await _notificationRepository.markAllAsRead(userId);
  }

  IconData iconForType(String type) {
    switch (type) {
      case 'booking':
        return Icons.sports_tennis_rounded;
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color colorForType(String type) {
    switch (type) {
      case 'booking':
        return AppColors.primary;
      case 'payment':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF757575);
    }
  }

  String timeLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return '';
    }

    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    if (diff.inDays == 1) {
      return 'Hôm qua';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    }

    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    return '$day/$month/${createdAt.year}';
  }

  void _watchNotifications() {
    isLoading.value = true;
    _notificationsSub = _notificationRepository
        .watchUserNotifications(userId)
        .listen(
          (items) {
            notifications.assignAll(items);
            isLoading.value = false;
            errorMessage.value = '';
          },
          onError: (_) {
            isLoading.value = false;
            errorMessage.value = 'notification.loadError'.tr;
          },
        );
  }

  @override
  void onClose() {
    _notificationsSub?.cancel();
    super.onClose();
  }
}
