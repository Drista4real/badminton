import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/app/booking_controller.dart';

class BookingBottomSheet {
  BookingBottomSheet._();

  static Future<void> pickDate(BuildContext context) {
    return Get.find<BookingController>().pickDate(context);
  }

  static void showTimeRange(BuildContext context) {
    Get.find<BookingController>().showTimeRangeSheet(context);
  }

  static void showOneTimeConfirm(BuildContext context) {
    Get.find<BookingController>().showOneTimeConfirmSheet(context);
  }

  static void showFixedTimePicker(
    BuildContext context, {
    required bool isStart,
  }) {
    Get.find<BookingController>().showFixedTimePickerSheet(
      context,
      isStart: isStart,
    );
  }
}
