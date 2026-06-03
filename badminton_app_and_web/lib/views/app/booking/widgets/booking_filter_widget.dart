import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../commons/styles/app_colors.dart';
import '../../../../controllers/app/booking_controller.dart';

class BookingHeader extends StatelessWidget {
  const BookingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              'nav.booking'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingTabs extends StatelessWidget {
  const BookingTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
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
          tabs: [
            Tab(child: FittedBox(child: Text('booking.oneTime'.tr))),
            Tab(child: FittedBox(child: Text('booking.fixed'.tr))),
          ],
        ),
      ),
    );
  }
}

class BookingFilterWidget extends GetView<BookingController> {
  const BookingFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _FilterButton(
                    icon: Icons.calendar_today_rounded,
                    label: controller.selectedDateLabel,
                    onTap: () => controller.pickDate(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterButton(
                    icon: Icons.access_time_rounded,
                    label:
                        '${controller.formatHour(controller.startHour.value)} - ${controller.formatHour(controller.endHour.value)}',
                    onTap: () => controller.showTimeRangeSheet(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Thảm:',
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    controller.matType.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TimeRangeSelectorWidget extends GetView<BookingController> {
  const TimeRangeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => controller.showTimeRangeSheet(context),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HourBadge(
                        controller.formatHour(controller.startHour.value),
                        AppColors.primary,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(color: AppColors.grey),
                        ),
                      ),
                      _HourBadge(
                        controller.formatHour(controller.endHour.value),
                        AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.zoom_out_rounded,
                  color: AppColors.grey,
                  size: 18,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                    ),
                    child: Slider(
                      value: controller.timelineScale.value,
                      min: BookingController.minTimelineScale,
                      max: BookingController.maxTimelineScale,
                      divisions: 4,
                      activeColor: AppColors.primary,
                      inactiveColor: const Color(0xFFEEEEEE),
                      onChanged: controller.setTimelineScale,
                    ),
                  ),
                ),
                const Icon(
                  Icons.zoom_in_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BookingLegendWidget extends StatelessWidget {
  const BookingLegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          _LegendItem(Color(0xFFF0FAF9), 'Trống', border: true),
          _LegendItem(AppColors.primary, 'Đã chọn'),
          _LegendItem(Color(0xFFEF5350), 'Đã đặt'),
          _LegendItem(Color(0xFFFFC107), 'Chờ thanh toán'),
          _LegendItem(Color(0xFF7E57C2), 'Cố định'),
          _LegendItem(Color(0xFFBDBDBD), 'Quá khứ'),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: Icon(icon, size: 13, color: AppColors.primary),
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(
              width: 18,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourBadge extends StatelessWidget {
  const _HourBadge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.label, {this.border = false});

  final Color color;
  final String label;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border ? Border.all(color: Colors.grey) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.grey),
        ),
      ],
    );
  }
}
