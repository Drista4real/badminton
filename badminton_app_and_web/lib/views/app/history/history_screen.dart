import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../commons/widgets/custom_button.dart';
import '../../../controllers/app/history_controller.dart';
import '../../../data/models/booking_model.dart';
import '../../../routes/app_routes.dart';

class HistoryScreen extends GetView<HistoryController> {
  final int initialIndex;

  const HistoryScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeInitialIndex = initialIndex.clamp(
      0,
      HistoryController.statusTabs.length - 1,
    );

    return DefaultTabController(
      length: HistoryController.statusTabs.length,
      initialIndex: safeInitialIndex,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary,
              size: 18,
            ),
            onPressed: controller.goBack,
          ),
          title: Text(
            'history.title'.tr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _HistoryTabBar(controller: controller),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty) {
            return _EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'history.loadErrorTitle'.tr,
              message: controller.errorMessage.value,
            );
          }

          return TabBarView(
            children: List.generate(HistoryController.statusTabs.length, (
              index,
            ) {
              return _BookingList(
                bookings: controller.bookingsForStatusTab(index),
                tabIndex: index,
              );
            }),
          );
        }),
        bottomNavigationBar: const _HistoryBottomNavigation(),
      ),
    );
  }
}

class _HistoryTabBar extends StatelessWidget {
  const _HistoryTabBar({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          onTap: controller.selectTab,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          dividerColor: Colors.transparent,
          tabs: HistoryController.statusTabs
              .map((label) => Tab(text: label))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _BookingList extends GetView<HistoryController> {
  const _BookingList({required this.bookings, required this.tabIndex});

  final List<BookingModel> bookings;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return _EmptyState(
        icon: _emptyIcon(tabIndex),
        title: controller.emptyTitleForTab(tabIndex),
        message: controller.emptyMessageForTab(tabIndex),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return controller.isFixedSchedule(booking)
            ? _FixedBookingCard(booking: booking)
            : _SingleBookingCard(booking: booking);
      },
    );
  }

  IconData _emptyIcon(int index) {
    switch (index) {
      case 1:
        return Icons.pending_actions_rounded;
      case 2:
        return Icons.task_alt_rounded;
      case 3:
        return Icons.cancel_outlined;
      default:
        return Icons.sports_tennis_rounded;
    }
  }
}

class _SingleBookingCard extends GetView<HistoryController> {
  const _SingleBookingCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return _HistoryCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CourtIcon(icon: Icons.sports_tennis_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.courtName(booking),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    _StatusChip(booking: booking),
                  ],
                ),
                const SizedBox(height: 10),
                _IconLabel(
                  icon: Icons.calendar_today_rounded,
                  text: 'Ngày: ${controller.bookingDateLabel(booking)}',
                ),
                const SizedBox(height: 6),
                _IconLabel(
                  icon: Icons.access_time_rounded,
                  text: 'Giờ: ${controller.timeRange(booking)}',
                ),
                const SizedBox(height: 10),
                _PriceText(amount: booking.totalPrice),
                Obx(() {
                  final isProcessing = controller.processingBookingIds.contains(
                    booking.id,
                  );
                  if (!controller.canCancelWithRefund(booking)) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => Get.bottomSheet<void>(
                              _CancelRefundSheet(booking: booking),
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                            ),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(isProcessing ? 'Đang xử lý' : 'Hủy đơn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        side: const BorderSide(color: Color(0xFFD32F2F)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedBookingCard extends GetView<HistoryController> {
  const _FixedBookingCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return _HistoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CourtIcon(icon: Icons.calendar_month_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.courtName(booking),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Đã đăng ký cố định',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(booking: booking),
            ],
          ),
          const Divider(height: 24),
          _IconLabel(
            icon: Icons.calendar_today_rounded,
            text: controller.fixedDaysLabel(booking),
          ),
          const SizedBox(height: 8),
          _IconLabel(
            icon: Icons.access_time_rounded,
            text: controller.timeRange(booking),
          ),
          const SizedBox(height: 8),
          _IconLabel(
            icon: Icons.timelapse_rounded,
            text: controller.fixedDurationLabel(booking),
          ),
          const SizedBox(height: 8),
          _IconLabel(
            icon: Icons.event_available_rounded,
            text: controller.nextSessionLabel(booking),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final isProcessing = controller.processingBookingIds.contains(
              booking.id,
            );
            final canReport = controller.canReportAbsence(booking);
            final canRenew = controller.shouldShowRenewButton(booking);

            if (!canReport && !canRenew) {
              return const _InfoBanner(
                text: 'Báo nghỉ chỉ mở trước giờ chơi ít nhất 24 giờ.',
              );
            }

            return Row(
              children: [
                if (canReport)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => controller.reportFixedAbsence(booking),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.event_busy_rounded, size: 18),
                      label: Text(isProcessing ? 'Đang xử lý' : 'Báo nghỉ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        side: const BorderSide(color: Color(0xFFD32F2F)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                if (canReport && canRenew) const SizedBox(width: 12),
                if (canRenew)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => controller.openRenewContractSheet(
                        _RenewContractSheet(booking: booking),
                      ),
                      icon: const Icon(Icons.autorenew_rounded, size: 18),
                      label: const Text('Gia hạn'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CancelRefundSheet extends StatefulWidget {
  const _CancelRefundSheet({required this.booking});

  final BookingModel booking;

  @override
  State<_CancelRefundSheet> createState() => _CancelRefundSheetState();
}

class _CancelRefundSheetState extends State<_CancelRefundSheet> {
  var _refundMethod = 'wallet';
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HistoryController>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text(
              'Hủy đơn đặt sân',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'wallet',
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  label: Text('Ví tiền'),
                ),
                ButtonSegment(
                  value: 'bank',
                  icon: Icon(Icons.account_balance_rounded),
                  label: Text('Ngân hàng'),
                ),
              ],
              selected: {_refundMethod},
              onSelectionChanged: (values) {
                setState(() => _refundMethod = values.first);
              },
            ),
            if (_refundMethod == 'bank') ...[
              const SizedBox(height: 14),
              TextField(
                controller: _bankNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Tên ngân hàng'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bankAccountNumberController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Số tài khoản'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bankAccountNameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Tên chủ thẻ'),
              ),
            ],
            const SizedBox(height: 20),
            Obx(() {
              final isProcessing = controller.processingBookingIds.contains(
                widget.booking.id,
              );

              return CustomButton(
                text: _refundMethod == 'wallet'
                    ? 'Hoàn vào Ví tiền'
                    : 'Gửi yêu cầu hoàn tiền',
                isLoading: isProcessing,
                onTap: () => controller.cancelBookingWithRefund(
                  booking: widget.booking,
                  refundMethod: _refundMethod,
                  bankName: _bankNameController.text.trim(),
                  bankAccountNumber: _bankAccountNumberController.text.trim(),
                  bankAccountName: _bankAccountNameController.text.trim(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RenewContractSheet extends GetView<HistoryController> {
  const _RenewContractSheet({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    var durationMonths = 1;

    return StatefulBuilder(
      builder: (context, setState) {
        final totalPrice = controller.renewalPrice(booking, durationMonths);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'Gia hạn: ${controller.courtName(booking)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn thời gian gia hạn thêm',
                style: TextStyle(fontSize: 12, color: AppColors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [1, 3, 6].map((month) {
                  final isSelected = durationMonths == month;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Center(child: Text('$month tháng')),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.grey,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          setState(() {
                            durationMonths = month;
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng tiền thanh toán',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  Text(
                    controller.formatMoney(totalPrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Obx(() {
                final isProcessing = controller.processingBookingIds.contains(
                  booking.id,
                );

                return CustomButton(
                  text: 'Tiến hành thanh toán',
                  isLoading: isProcessing,
                  onTap: () => controller.renewFixedBookingFromSheet(
                    booking,
                    durationMonths,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CourtIcon extends StatelessWidget {
  const _CourtIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

class _StatusChip extends GetView<HistoryController> {
  const _StatusChip({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: controller.statusBackgroundColor(booking.status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        controller.statusLabel(booking.status),
        style: TextStyle(
          color: controller.statusColor(booking.status),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceText extends GetView<HistoryController> {
  const _PriceText({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'Giá: ',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: controller.formatMoney(amount),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.primary.withAlpha(160)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBottomNavigation extends GetView<HistoryController> {
  const _HistoryBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(Icons.home_rounded, 'nav.home', AppRoutes.home),
      _NavItem(Icons.sports_tennis_rounded, 'nav.booking', AppRoutes.booking),
      _NavItem(
        Icons.account_balance_wallet_rounded,
        'nav.wallet',
        AppRoutes.wallet,
      ),
      _NavItem(
        Icons.notifications_rounded,
        'nav.notification',
        AppRoutes.notification,
      ),
      _NavItem(Icons.person_rounded, 'nav.profile', AppRoutes.profile),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
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
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = item.route == Get.currentRoute;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => controller.navigateFromBottomNav(
                  item.route,
                  isSelected: isSelected,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withAlpha(24)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected ? AppColors.primary : AppColors.grey,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label.tr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.grey,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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

class _NavItem {
  const _NavItem(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}
