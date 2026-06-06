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
          isScrollable: false,
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
          labelPadding: EdgeInsets.zero,
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
      case 4:
        return Icons.calendar_month_rounded;
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
                              backgroundColor: Colors.transparent,
                              elevation: 0,
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
            icon: Icons.event_rounded,
            text: 'Buổi chơi: ${controller.bookingDateLabel(booking)}',
          ),
          const SizedBox(height: 8),
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
  final _formKey = GlobalKey<FormState>();
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get _bookingTimeReference {
    return '${_formatDate(widget.booking.bookingDate)} '
        '${_formatMinutes(widget.booking.startTime)} - '
        '${_formatMinutes(widget.booking.endTime)}';
  }

  void _submit(HistoryController controller) {
    if (_refundMethod == 'bank' &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    controller.cancelBookingWithRefund(
      booking: widget.booking,
      refundMethod: _refundMethod,
      bankName: _bankNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text.trim(),
      bankAccountName: _bankAccountNameController.text.trim(),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập đầy đủ thông tin';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HistoryController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isBankRefund = _refundMethod == 'bank';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.event_busy_rounded,
                            color: Color(0xFFD32F2F),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hủy đơn đặt sân',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Chọn nơi nhận khoản tiền được hoàn',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: Get.back<void>,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.sports_tennis_rounded,
                              color: colors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.courtName(widget.booking),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _bookingTimeReference,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            controller.formatMoney(widget.booking.totalPrice),
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Phương thức hoàn tiền',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RefundMethodCard(
                            icon: Icons.account_balance_wallet_rounded,
                            title: 'Ví tiền',
                            subtitle: 'Nhận ngay trên ứng dụng',
                            isSelected: !isBankRefund,
                            onTap: () {
                              setState(() => _refundMethod = 'wallet');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RefundMethodCard(
                            icon: Icons.account_balance_rounded,
                            title: 'Ngân hàng',
                            subtitle: 'Kế toán chuyển khoản',
                            isSelected: isBankRefund,
                            onTap: () {
                              setState(() => _refundMethod = 'bank');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isBankRefund
                          ? Column(
                              key: const ValueKey('bank-refund-form'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _RefundNotice(
                                  icon: Icons.schedule_rounded,
                                  text:
                                      'Yêu cầu sẽ xuất hiện trên trang kế toán. '
                                      'Tiền được chuyển thủ công sau khi đối soát.',
                                  color: Color(0xFF9A5B00),
                                  backgroundColor: Color(0xFFFFF8E8),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tài khoản nhận tiền',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _bankNameController,
                                  textInputAction: TextInputAction.next,
                                  validator: _requiredField,
                                  decoration: _fieldDecoration(
                                    context,
                                    label: 'Tên ngân hàng',
                                    icon: Icons.account_balance_rounded,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _bankAccountNumberController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  validator: _requiredField,
                                  decoration: _fieldDecoration(
                                    context,
                                    label: 'Số tài khoản',
                                    icon: Icons.numbers_rounded,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _bankAccountNameController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textInputAction: TextInputAction.done,
                                  validator: _requiredField,
                                  onFieldSubmitted: (_) => _submit(controller),
                                  decoration: _fieldDecoration(
                                    context,
                                    label: 'Tên chủ tài khoản',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ),
                              ],
                            )
                          : const _RefundNotice(
                              key: ValueKey('wallet-refund-notice'),
                              icon: Icons.bolt_rounded,
                              text:
                                  'Khoản hoàn sẽ được cộng trực tiếp vào số dư '
                                  'Ví tiền ngay sau khi hủy đơn thành công.',
                              color: AppColors.primary,
                              backgroundColor: Color(0xFFEFFAF8),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Obx(() {
                      final isProcessing = controller.processingBookingIds
                          .contains(widget.booking.id);

                      return CustomButton(
                        text: isBankRefund
                            ? 'Gửi yêu cầu cho kế toán'
                            : 'Hủy đơn và hoàn vào Ví',
                        isLoading: isProcessing,
                        onTap: () => _submit(controller),
                      );
                    }),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Số tiền hoàn được tính theo chính sách tại thời điểm hủy.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outlineVariant),
    );

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    );
  }
}

class _RefundMethodCard extends StatelessWidget {
  const _RefundMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = isSelected ? colors.primary : colors.onSurfaceVariant;

    return Material(
      color: isSelected
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.primary : colors.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: foreground, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundNotice extends StatelessWidget {
  const _RefundNotice({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
