import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../controllers/app/booking_controller.dart';
import 'widgets/booking_filter_widget.dart';
import 'widgets/fixed_booking_widget.dart';
import 'widgets/time_grid_widget.dart';

class BookingScreen extends GetView<BookingController> {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              const BookingHeader(),
              const BookingTabs(),
              Obx(() {
                final message = controller.errorMessage.value;
                if (message.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3E0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
              const Expanded(
                child: TabBarView(
                  physics: NeverScrollableScrollPhysics(),
                  children: [OneTimeBookingView(), FixedBookingView()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OneTimeBookingView extends GetView<BookingController> {
  const OneTimeBookingView({super.key});

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

      if (controller.courts.isEmpty) {
        final apiError = controller.errorMessage.value;
        return Center(
          child: Text(
            apiError.isNotEmpty ? apiError : 'Chưa có sân phù hợp để đặt.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        );
      }

      return Stack(
        children: [
          const SingleChildScrollView(
            child: Column(
              children: [
                BookingFilterWidget(),
                TimeRangeSelectorWidget(),
                SizedBox(height: 6),
                TimeGridWidget(),
                SizedBox(height: 10),
                BookingLegendWidget(),
                SizedBox(height: 100),
              ],
            ),
          ),
          if (controller.selectedSlotKeys.isNotEmpty)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: OneTimeConfirmBar(),
            ),
        ],
      );
    });
  }
}
