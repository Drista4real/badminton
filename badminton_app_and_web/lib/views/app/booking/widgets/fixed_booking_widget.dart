import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../commons/styles/app_colors.dart';
import '../../../../controllers/app/booking_controller.dart';
import '../../../../commons/widgets/custom_button.dart';

class FixedBookingView extends GetView<BookingController> {
  const FixedBookingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingCourts.value ||
          controller.isLoadingBookings.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      if (controller.bookingScheduleError.value.isNotEmpty) {
        return Center(
          child: Text(
            controller.bookingScheduleError.value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        );
      }

      return Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
            child: Column(
              children: [
                const _FixedConfigCard(),
                const SizedBox(height: 12),
                const _AvailableFixedCourtsCard(),
                if (controller.canShowFixedSummary) ...[
                  const SizedBox(height: 12),
                  const _FixedSummaryCard(),
                ],
              ],
            ),
          ),
          if (controller.canShowFixedSummary) const _FixedPaymentBar(),
        ],
      );
    });
  }
}

class OneTimeConfirmBar extends GetView<BookingController> {
  const OneTimeConfirmBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sân ${controller.selectedCourtNumbers.join(', ')}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                      Text(
                        '${controller.matType.value} - ${controller.formatBookingRange(controller.selectedStartTime, controller.selectedEndTime)} - ${controller.formatDuration(controller.selectedDurationMinutes)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  controller.formatMoney(controller.totalPrice),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'Xác nhận đặt sân',
              onTap: () => controller.showOneTimeConfirmSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedConfigCard extends GetView<BookingController> {
  const _FixedConfigCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cấu hình lịch cố định',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chọn ngày trong tuần',
            style: TextStyle(fontSize: 12, color: AppColors.grey),
          ),
          const SizedBox(height: 8),
          Obx(
            () => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: controller.weekdays.map((day) {
                  final isSelected = controller.selectedWeekdays.contains(day);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => controller.toggleWeekday(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFF0FAF9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.grey,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Khung giờ',
            style: TextStyle(fontSize: 12, color: AppColors.grey),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: _FixedTimeBox(
                    controller.formatHour(controller.fixedStart.value),
                    () => controller.showFixedTimePickerSheet(
                      context,
                      isStart: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '-',
                    style: TextStyle(fontSize: 20, color: Colors.grey.shade400),
                  ),
                ),
                Expanded(
                  child: _FixedTimeBox(
                    controller.formatHour(controller.fixedEnd.value),
                    () => controller.showFixedTimePickerSheet(
                      context,
                      isStart: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kỳ hạn đăng ký',
            style: TextStyle(fontSize: 12, color: AppColors.grey),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<int>(
                value: controller.months.value,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
                items: const [1, 3, 6]
                    .map(
                      (month) => DropdownMenuItem(
                        value: month,
                        child: Text('$month tháng'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) controller.setMonths(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableFixedCourtsCard extends GetView<BookingController> {
  const _AvailableFixedCourtsCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final courts = controller.availableFixedCourts;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Danh sách sân trống',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                GestureDetector(
                  onTap: controller.toggleAllFixedCourts,
                  child: Text(
                    controller.selectedFixedCourtIds.length == courts.length
                        ? 'Bỏ chọn tất cả'
                        : 'Chọn tất cả',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (courts.isEmpty)
              const Text(
                'Không có sân trống phù hợp.',
                style: TextStyle(fontSize: 12, color: AppColors.grey),
              )
            else
              ...courts.map((court) {
                final isSelected = controller.selectedFixedCourtIds.contains(
                  court.id,
                );
                final price = controller.fixedSessionPriceInThousands * 1000;
                return GestureDetector(
                  onTap: () => controller.toggleFixedCourt(court.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _CourtThumbnail(imageUrl: court.imageUrl),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.courtName(court),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black,
                                ),
                              ),
                              Text(
                                '${court.surfaceType.isEmpty ? controller.matType.value : court.surfaceType} - ${controller.formatHour(controller.fixedStart.value)} - ${controller.formatHour(controller.fixedEnd.value)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.grey,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${controller.formatMoney(price)}/buổi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    });
  }
}

class _CourtThumbnail extends StatelessWidget {
  const _CourtThumbnail({required this.imageUrl});

  static const _fallbackAsset = 'assets/images/sancaulong.jpg';

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _fallbackImage();
    }

    return Image.network(
      url,
      width: 60,
      height: 50,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _fallbackImage();
      },
      errorBuilder: (context, error, stackTrace) => _fallbackImage(),
    );
  }

  static Widget _fallbackImage() {
    return Image.asset(
      _fallbackAsset,
      width: 60,
      height: 50,
      fit: BoxFit.cover,
    );
  }
}

class _FixedSummaryCard extends GetView<BookingController> {
  const _FixedSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tóm tắt hợp đồng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: controller.toggleSummary,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        controller.showSummary.value
                            ? Icons.close_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: AppColors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (controller.showSummary.value) ...[
              const Divider(height: 20, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _SummaryRow(
                      'Số ngày/tuần',
                      '${controller.selectedWeekdays.length} ngày (${controller.selectedWeekdaysLabel})',
                    ),
                    _SummaryRow(
                      'Thời gian',
                      '${controller.formatHour(controller.fixedStart.value)} - ${controller.formatHour(controller.fixedEnd.value)} (${controller.formatDuration((controller.fixedHours * BookingController.minutesPerHour).round())})',
                    ),
                    _SummaryRow('Kỳ hạn', '${controller.months.value} tháng'),
                    _SummaryRow(
                      'Số sân đặt',
                      '${controller.selectedFixedCourtIds.length} sân',
                    ),
                    _SummaryRow(
                      'Tổng buổi',
                      '${controller.fixedSessionCount} buổi',
                    ),
                    _SummaryRow(
                      'Đơn giá',
                      '${controller.formatMoney(controller.fixedSessionPriceInThousands * 1000)}/buổi/sân',
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng tiền tạm tính',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          controller.formatMoney(controller.fixedTotal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FixedPaymentBar extends GetView<BookingController> {
  const _FixedPaymentBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Obx(
        () => Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FAF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFE9D7)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FixedPaymentInfoRow(
                      Icons.sports_tennis_rounded,
                      'Sân',
                      controller.selectedFixedCourtNames,
                    ),
                    const SizedBox(height: 6),
                    _FixedPaymentInfoRow(
                      Icons.event_repeat_rounded,
                      'Ngày chơi',
                      '${controller.selectedWeekdaysLabel} • ${controller.fixedSessionCount} buổi',
                    ),
                    const SizedBox(height: 6),
                    _FixedPaymentInfoRow(
                      Icons.date_range_rounded,
                      'Thời hạn',
                      controller.fixedDateRangeLabel,
                    ),
                    const SizedBox(height: 6),
                    _FixedPaymentInfoRow(
                      Icons.schedule_rounded,
                      'Giờ chơi',
                      controller.fixedTimeRangeLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tổng tiền tạm tính',
                          style: TextStyle(fontSize: 11, color: AppColors.grey),
                        ),
                        Text(
                          controller.formatMoney(controller.fixedTotal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: controller.isSubmitting.value
                          ? 'Đang tạo đơn...'
                          : 'Thanh toán',
                      onTap: controller.isSubmitting.value
                          ? () {}
                          : controller.submitFixedBooking,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FixedPaymentInfoRow extends StatelessWidget {
  const _FixedPaymentInfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.black,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _FixedTimeBox extends StatelessWidget {
  const _FixedTimeBox(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.grey),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
