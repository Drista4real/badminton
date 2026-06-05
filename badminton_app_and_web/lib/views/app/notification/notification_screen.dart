import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../controllers/app/notification_controller.dart';
import '../../../data/models/notification_model.dart';

// Lưu file này bằng UTF-8 trong IDE để giữ đúng dấu tiếng Việt.
class NotificationScreen extends GetView<NotificationController> {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabs(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: Get.back,
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
              'notification.title'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          Obx(() {
            if (controller.unreadCount == 0) {
              return const SizedBox.shrink();
            }

            return GestureDetector(
              onTap: controller.markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'notification.markAllRead'.tr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          () => Row(
            children: List.generate(NotificationController.tabs.length, (
              index,
            ) {
              final isSelected = controller.selectedTab.value == index;
              final unreadCount = controller.unreadCountForTab(index);
              return Padding(
                padding: EdgeInsets.only(
                  right: index == NotificationController.tabs.length - 1
                      ? 0
                      : 8,
                ),
                child: GestureDetector(
                  onTap: () => controller.selectTab(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFFF0FAF9),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFE2F3F1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          NotificationController.tabs[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              unreadCount > 99
                                  ? '99+'
                                  : unreadCount.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.red,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.errorMessage.value.isNotEmpty) {
        return _buildEmpty(controller.errorMessage.value);
      }

      final items = controller.filteredNotifications;
      if (items.isEmpty) {
        return _buildEmpty('notification.empty'.tr);
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
                  'notification.end'.tr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
            );
          }

          return _buildNotificationCard(items[i]);
        },
      );
    });
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item) {
    final isRead = item.isRead;
    final color = controller.colorForType(item.type);

    return GestureDetector(
      onTap: () => controller.markAsRead(item),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  controller.iconForType(item.type),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          controller.timeLabel(item.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? AppColors.grey : AppColors.black,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 2),
                  width: 8,
                  height: 8,
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
