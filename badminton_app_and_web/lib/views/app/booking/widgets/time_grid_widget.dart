import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../commons/styles/app_colors.dart';
import '../../../../controllers/app/booking_controller.dart';

class TimeGridWidget extends GetView<BookingController> {
  const TimeGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final startIndex = controller.startIndex;
      final visibleSlotStarts = controller.visibleSlotStarts;
      final cellWidth = controller.timeGridCellWidth;
      final gridWidth = visibleSlotStarts.length * cellWidth;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _TimeGridMetrics.frozenColumnWidth,
              child: Column(
                children: [
                  const _FrozenHeaderCell(),
                  ...List.generate(
                    controller.courts.length,
                    (courtIndex) => _FrozenCourtCell(
                      label: controller.courtCodeAt(courtIndex),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    children: [
                      _TimeAxis(
                        slotStarts: visibleSlotStarts,
                        cellWidth: cellWidth,
                      ),
                      ...List.generate(
                        controller.courts.length,
                        (courtIndex) => _CourtSlotsRow(
                          courtIndex: courtIndex,
                          startIndex: startIndex,
                          slotCount: visibleSlotStarts.length,
                          cellWidth: cellWidth,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TimeGridMetrics {
  static const frozenColumnWidth = 56.0;
  static const headerHeight = 34.0;
  static const rowHeight = 38.0;
  static const dividerHeight = 1.0;
  static const headerExtent = headerHeight + dividerHeight;
  static const rowExtent = rowHeight + dividerHeight;
}

class _FrozenHeaderCell extends StatelessWidget {
  const _FrozenHeaderCell();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _TimeGridMetrics.headerExtent,
      child: Column(
        children: [
          const SizedBox(
            height: _TimeGridMetrics.headerHeight,
            child: Center(
              child: Text(
                'Sân',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

class _FrozenCourtCell extends StatelessWidget {
  const _FrozenCourtCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _TimeGridMetrics.rowExtent,
      child: Column(
        children: [
          SizedBox(
            height: _TimeGridMetrics.rowHeight,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.slotStarts, required this.cellWidth});

  final List<int> slotStarts;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _TimeGridMetrics.headerExtent,
      child: Column(
        children: [
          SizedBox(
            height: _TimeGridMetrics.headerHeight,
            child: Row(
              children: slotStarts
                  .map(
                    (slotStart) =>
                        _TimeAxisSlot(slotStart: slotStart, width: cellWidth),
                  )
                  .toList(),
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

class _TimeAxisSlot extends GetView<BookingController> {
  const _TimeAxisSlot({required this.slotStart, required this.width});

  final int slotStart;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Center(child: _TickLabel(controller.formatMinutes(slotStart))),
      ),
    );
  }
}

class _TickLabel extends StatelessWidget {
  const _TickLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.grey,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CourtSlotsRow extends StatelessWidget {
  const _CourtSlotsRow({
    required this.courtIndex,
    required this.startIndex,
    required this.slotCount,
    required this.cellWidth,
  });

  final int courtIndex;
  final int startIndex;
  final int slotCount;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _TimeGridMetrics.rowExtent,
      child: Column(
        children: [
          SizedBox(
            height: _TimeGridMetrics.rowHeight,
            child: Row(
              children: List.generate(
                slotCount,
                (slotOffset) => _TimeSlotCell(
                  courtIndex: courtIndex,
                  slotIndex: startIndex + slotOffset,
                  width: cellWidth,
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

class _TimeSlotCell extends GetView<BookingController> {
  const _TimeSlotCell({
    required this.courtIndex,
    required this.slotIndex,
    required this.width,
  });

  final int courtIndex;
  final int slotIndex;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.slotStatus(courtIndex, slotIndex);
      final isSelected = controller.isSlotSelected(courtIndex, slotIndex);
      final canSelect = status == BookingSlotStatus.available;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canSelect
            ? () => controller.toggleSlot(courtIndex, slotIndex)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: width,
          height: _TimeGridMetrics.rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _cellColor(status, isSelected),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _cellBorderColor(status, isSelected),
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [_cellIcon(status, isSelected)],
            ),
          ),
        ),
      );
    });
  }

  Color _cellColor(BookingSlotStatus status, bool isSelected) {
    if (isSelected) return AppColors.primary;

    return switch (status) {
      BookingSlotStatus.booked => const Color(0xFFEF5350),
      BookingSlotStatus.pending => const Color(0xFFFFC107),
      BookingSlotStatus.fixed => const Color(0xFF7E57C2),
      BookingSlotStatus.past => const Color(0xFFBDBDBD),
      BookingSlotStatus.available => const Color(0xFFF0FAF9),
      BookingSlotStatus.selected => AppColors.primary,
    };
  }

  Color _cellBorderColor(BookingSlotStatus status, bool isSelected) {
    if (isSelected) return const Color(0xFF06645F);

    return switch (status) {
      BookingSlotStatus.available => const Color(0xFFBFE9D7),
      BookingSlotStatus.pending => const Color(0xFFE5A800),
      BookingSlotStatus.fixed => const Color(0xFF6A45B0),
      BookingSlotStatus.booked => const Color(0xFFD94340),
      BookingSlotStatus.past => const Color(0xFFA7A7A7),
      BookingSlotStatus.selected => const Color(0xFF06645F),
    };
  }

  Widget _cellIcon(BookingSlotStatus status, bool isSelected) {
    if (isSelected) {
      return const Icon(Icons.check_rounded, size: 16, color: Colors.white);
    }

    return switch (status) {
      BookingSlotStatus.available => const Icon(
        Icons.star_border_rounded,
        size: 13,
        color: AppColors.grey,
      ),
      BookingSlotStatus.pending => const Icon(
        Icons.schedule_rounded,
        size: 14,
        color: Colors.white,
      ),
      BookingSlotStatus.fixed => const Icon(
        Icons.event_repeat_rounded,
        size: 14,
        color: Colors.white,
      ),
      BookingSlotStatus.booked => const Icon(
        Icons.lock_rounded,
        size: 13,
        color: Colors.white,
      ),
      BookingSlotStatus.past => const SizedBox.shrink(),
      BookingSlotStatus.selected => const Icon(
        Icons.check_rounded,
        size: 16,
        color: Colors.white,
      ),
    };
  }
}
