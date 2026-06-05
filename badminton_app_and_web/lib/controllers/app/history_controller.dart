import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commons/styles/app_colors.dart';
import '../../constants/enums/app_enums.dart';
import '../../data/models/booking_model.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/booking_repository.dart';
import '../../routes/app_routes.dart';
import '../../utils/currency_format.dart';
import '../../utils/date_format.dart';

class HistoryController extends GetxController {
  HistoryController({
    required BookingRepository bookingRepository,
    required AuthRepository authRepository,
  }) : _bookingRepository = bookingRepository,
       _authRepository = authRepository;

  final BookingRepository _bookingRepository;
  final AuthRepository _authRepository;

  final selectedTabIndex = 0.obs;
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final oneTimeBookings = <BookingModel>[].obs;
  final fixedBookings = <BookingModel>[].obs;
  final processingBookingIds = <String>{}.obs;

  StreamSubscription<List<BookingModel>>? _bookingSubscription;

  static const statusTabKeys = [
    'history.tab.all',
    'history.tab.booked',
    'history.tab.completed',
    'history.tab.cancelled',
    'history.tab.contracts',
  ];

  static List<String> get statusTabs =>
      statusTabKeys.map((key) => key.tr).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    selectedTabIndex.value = _initialIndexFromRoute();
    _listenBookings();
  }

  @override
  void onClose() {
    _bookingSubscription?.cancel();
    super.onClose();
  }

  void selectTab(int index) {
    selectedTabIndex.value = index;
  }

  List<BookingModel> bookingsForStatusTab(int index) {
    final items = [...oneTimeBookings, ...fixedBookings]
      ..sort((left, right) {
        final leftDate = left.fixedStartDate ?? left.bookingDate;
        final rightDate = right.fixedStartDate ?? right.bookingDate;
        return rightDate.compareTo(leftDate);
      });

    return items.where((booking) => _matchesStatusTab(booking, index)).toList();
  }

  String emptyTitleForTab(int index) {
    switch (index) {
      case 1:
        return 'Chưa có đơn đang đặt';
      case 2:
        return 'Chưa có đơn đã kết thúc';
      case 3:
        return 'Chưa có đơn đã hủy';
      case 4:
        return 'Chưa có hợp đồng cố định';
      default:
        return 'Chưa có lịch sử đặt sân';
    }
  }

  String emptyMessageForTab(int index) {
    switch (index) {
      case 1:
        return 'Các đơn chờ thanh toán hoặc đã xác nhận sẽ hiển thị tại đây.';
      case 2:
        return 'Các lượt chơi đã hoàn thành sẽ hiển thị tại đây.';
      case 3:
        return 'Các đơn đã hủy hoặc đã báo nghỉ sẽ hiển thị tại đây.';
      case 4:
        return 'Các buổi chơi trong hợp đồng cố định của bạn sẽ hiển thị tại đây.';
      default:
        return 'Các đơn đặt sân của bạn sẽ hiển thị tại đây.';
    }
  }

  void goBack() {
    final navigator = Get.key.currentState;
    if (navigator?.canPop() == true) {
      Get.back<void>();
      return;
    }

    Get.offAllNamed(AppRoutes.home);
  }

  void navigateFromBottomNav(String route, {required bool isSelected}) {
    if (isSelected) {
      return;
    }

    Get.offNamed(route);
  }

  bool isFixedSchedule(BookingModel booking) {
    return booking.bookingType == BookingType.fixed ||
        booking.fixedWeekdays.isNotEmpty ||
        booking.fixedDurationMonths != null;
  }

  bool canReportAbsence(BookingModel booking) {
    if (!isFixedSchedule(booking)) {
      return false;
    }
    if (_isCancelled(booking.status)) {
      return false;
    }
    if (booking.status != OrderStatus.confirmed &&
        booking.status != OrderStatus.paid) {
      return false;
    }

    return sessionStart(booking).difference(DateTime.now()) >
        const Duration(hours: 24);
  }

  bool canCancelWithRefund(BookingModel booking) {
    if (isFixedSchedule(booking)) {
      return false;
    }
    if (booking.status != OrderStatus.confirmed &&
        booking.status != OrderStatus.paid) {
      return false;
    }
    return sessionStart(booking).isAfter(DateTime.now());
  }

  bool shouldShowRenewButton(BookingModel booking) {
    if (!isFixedSchedule(booking)) {
      return false;
    }
    if (_isCancelled(booking.status)) {
      return false;
    }

    final endDate = booking.fixedEndDate;
    if (endDate == null) {
      return true;
    }

    return endDate.difference(DateTime.now()).inDays <= 7;
  }

  DateTime? nextSessionStart(BookingModel booking) {
    final now = DateTime.now();
    final startDate = _dateOnly(booking.fixedStartDate ?? booking.bookingDate);
    final endDate = booking.fixedEndDate == null
        ? startDate.add(const Duration(days: 370))
        : _dateOnly(booking.fixedEndDate!);
    final searchStart = _dateOnly(now.isAfter(startDate) ? now : startDate);
    final weekdays = _fixedWeekdays(booking);

    for (var i = 0; i <= 370; i++) {
      final day = searchStart.add(Duration(days: i));
      if (day.isAfter(endDate)) {
        break;
      }
      if (!weekdays.contains(day.weekday)) {
        continue;
      }

      final sessionStart = DateTime(
        day.year,
        day.month,
        day.day,
        booking.startTime ~/ 60,
        booking.startTime % 60,
      );
      if (sessionStart.isAfter(now)) {
        return sessionStart;
      }
    }

    return null;
  }

  Future<void> reportFixedAbsence(BookingModel booking) async {
    if (!canReportAbsence(booking)) {
      Get.snackbar(
        'Không thể báo nghỉ',
        'Bạn chỉ có thể báo nghỉ trước giờ chơi ít nhất 24 giờ.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    processingBookingIds.add(booking.id);
    try {
      final result = await _bookingRepository.reportFixedAbsence(
        bookingId: booking.id,
      );
      if (result.refundedAmount < 0) {
        return;
      }
      Get.snackbar(
        'Đã báo nghỉ',
        'Buổi cố định đã được hủy. Hệ thống sẽ hoàn tiền 100% vào ví.',
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
      );
    } on BookingApiException catch (error) {
      Get.snackbar(
        'Không thể báo nghỉ',
        error.message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Không thể báo nghỉ',
        'Vui lòng thử lại sau.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      processingBookingIds.remove(booking.id);
    }
  }

  Future<void> cancelBookingWithRefund({
    required BookingModel booking,
    required String refundMethod,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    final orderId = booking.orderId;
    if (orderId == null || orderId.isEmpty) {
      Get.snackbar(
        'Không thể hủy đơn',
        'Đơn đặt sân thiếu mã đơn hàng.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    processingBookingIds.add(booking.id);
    try {
      final result = await _bookingRepository.cancelBookingWithRefund(
        orderId: orderId,
        refundMethod: refundMethod,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        bankAccountName: bankAccountName,
      );
      if (Get.isBottomSheetOpen == true) {
        Get.back<void>();
      }

      Get.snackbar(
        'Đã ghi nhận hủy đơn',
        result.refundMethod == 'wallet'
            ? 'Đã hoàn ${formatMoney(result.refundAmount)} vào Ví tiền.'
            : 'Yêu cầu hoàn ${formatMoney(result.refundAmount)} đang chờ kế toán xử lý.',
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
      );
    } on BookingApiException catch (error) {
      Get.snackbar(
        'Không thể hủy đơn',
        error.message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Không thể hủy đơn',
        'Vui lòng thử lại sau.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      processingBookingIds.remove(booking.id);
    }
  }

  double renewalPrice(BookingModel booking, int durationMonths) {
    final baseMonths = booking.fixedDurationMonths ?? 1;
    final monthlyPrice = baseMonths <= 0
        ? booking.totalPrice
        : booking.totalPrice / baseMonths;
    return monthlyPrice * durationMonths;
  }

  void openRenewContractSheet(Widget sheet) {
    Get.bottomSheet<void>(
      sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  void closeRenewContractSheet() {
    if (Get.isBottomSheetOpen == true) {
      Get.back<void>();
    }
  }

  Future<void> renewFixedBookingFromSheet(
    BookingModel booking,
    int durationMonths,
  ) async {
    final success = await renewFixedBooking(booking, durationMonths);
    if (success) {
      closeRenewContractSheet();
    }
  }

  Future<bool> renewFixedBooking(
    BookingModel booking,
    int durationMonths,
  ) async {
    final oldOrderId = booking.orderId;
    if (oldOrderId == null || oldOrderId.isEmpty) {
      Get.snackbar(
        'Không thể gia hạn',
        'Lịch cũ thiếu mã đơn hàng.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    processingBookingIds.add(booking.id);
    try {
      final result = await _bookingRepository.renewFixedBookingViaApi(
        oldOrderId: oldOrderId,
        durationMonths: durationMonths,
      );

      handleRenewNavigation(booking, result, durationMonths);
      return true;
    } on BookingConflictException {
      Get.snackbar(
        'Trùng lịch',
        'Không thể gia hạn vì lịch mới đã có người đặt.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Không thể gia hạn',
        'Vui lòng thử lại sau.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      processingBookingIds.remove(booking.id);
    }

    return false;
  }

  void handleRenewNavigation(
    BookingModel booking,
    RenewFixedBookingApiResult result,
    int durationMonths,
  ) {
    Get.toNamed(
      AppRoutes.payment,
      arguments: {
        'courtName': '${courtName(booking)} (Gia hạn)',
        'price': result.totalPrice > 0
            ? result.totalPrice
            : renewalPrice(booking, durationMonths),
        'date': 'Gia hạn từ ngày tiếp theo',
        'time': timeRange(booking),
        'isFixed': true,
        'fixedDuration': '$durationMonths tháng',
        'orderId': result.orderId,
        'bookingIds': result.bookingIds,
      },
    );
  }

  String courtName(BookingModel booking) {
    if (booking.courtId.isEmpty) {
      return 'Sân cầu lông';
    }
    return 'Sân ${booking.courtId}';
  }

  String bookingDateLabel(BookingModel booking) {
    return formatDate(booking.bookingDate);
  }

  String fixedDaysLabel(BookingModel booking) {
    final weekdays = _fixedWeekdays(booking).toList()..sort();
    if (weekdays.isEmpty) {
      return 'Lịch cố định';
    }

    final labels = weekdays.map(_weekdayLabel).join(', ');
    return '$labels hàng tuần';
  }

  String fixedDurationLabel(BookingModel booking) {
    final start = booking.fixedStartDate;
    final end = booking.fixedEndDate;
    if (start == null && end == null) {
      final months = booking.fixedDurationMonths;
      return months == null ? 'Thời hạn cố định' : 'Thời hạn: $months tháng';
    }

    final startText = start == null ? '...' : formatDate(start);
    final endText = end == null ? '...' : formatDate(end);
    return 'Thời hạn: $startText - $endText';
  }

  String nextSessionLabel(BookingModel booking) {
    final session = nextSessionStart(booking);
    if (session == null) {
      return 'Chưa có buổi sắp tới';
    }
    return 'Buổi tới: ${formatDate(session)}';
  }

  DateTime sessionStart(BookingModel booking) {
    final date = booking.bookingDate;
    return DateTime(
      date.year,
      date.month,
      date.day,
      booking.startTime ~/ 60,
      booking.startTime % 60,
    );
  }

  String timeRange(BookingModel booking) {
    return '${_minuteText(booking.startTime)} - ${_minuteText(booking.endTime)}';
  }

  String statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Chờ thanh toán';
      case OrderStatus.confirmed:
      case OrderStatus.paid:
        return 'Đã xác nhận';
      case OrderStatus.completed:
        return 'Hoàn thành';
      case OrderStatus.cancelled:
        return 'Đã hủy';
      case OrderStatus.cancelledByUserFixed:
        return 'Đã báo nghỉ';
      case OrderStatus.refundPending:
        return 'Chờ hoàn tiền';
      case OrderStatus.noShow:
        return 'Vắng mặt';
    }
  }

  Color statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFF9800);
      case OrderStatus.confirmed:
      case OrderStatus.paid:
        return AppColors.primary;
      case OrderStatus.completed:
        return const Color(0xFF2E7D32);
      case OrderStatus.cancelled:
      case OrderStatus.cancelledByUserFixed:
      case OrderStatus.refundPending:
      case OrderStatus.noShow:
        return const Color(0xFFD32F2F);
    }
  }

  Color statusBackgroundColor(OrderStatus status) {
    return statusColor(status).withAlpha(20);
  }

  String formatMoney(double amount) => CurrencyFormat.vnd(amount);

  String formatDate(DateTime date) => DateFormatUtils.dayMonthYear(date);

  void _listenBookings() {
    final userId = _requireCurrentUserId();
    isLoading.value = true;
    errorMessage.value = '';

    _bookingSubscription?.cancel();
    _bookingSubscription = _bookingRepository
        .watchUserBookings(userId)
        .listen(
          _applyBookings,
          onError: (_) {
            isLoading.value = false;
            errorMessage.value = 'Không thể tải lịch sử đặt sân.';
          },
        );
  }

  void _applyBookings(List<BookingModel> bookings) {
    final single = <BookingModel>[];
    final fixed = <BookingModel>[];

    for (final booking in bookings) {
      if (isFixedSchedule(booking)) {
        fixed.add(booking);
      } else {
        single.add(booking);
      }
    }

    single.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
    fixed.sort((a, b) {
      final aDate = a.fixedStartDate ?? a.bookingDate;
      final bDate = b.fixedStartDate ?? b.bookingDate;
      return bDate.compareTo(aDate);
    });

    oneTimeBookings.assignAll(single);
    fixedBookings.assignAll(fixed);
    isLoading.value = false;
  }

  int _initialIndexFromRoute() {
    final args = Get.arguments;
    if (args is Map<String, dynamic>) {
      final index = args['initialIndex'] as int? ?? 0;
      return index.clamp(0, statusTabs.length - 1);
    }
    return 0;
  }

  bool _matchesStatusTab(BookingModel booking, int index) {
    switch (index) {
      case 1:
        return booking.status == OrderStatus.pending ||
            booking.status == OrderStatus.confirmed ||
            booking.status == OrderStatus.paid;
      case 2:
        return booking.status == OrderStatus.completed;
      case 3:
        return _isCancelled(booking.status);
      case 4:
        return isFixedSchedule(booking);
      default:
        return true;
    }
  }

  Set<int> _fixedWeekdays(BookingModel booking) {
    final values = booking.fixedWeekdays
        .map(_weekdayNumberFromLabel)
        .whereType<int>()
        .toSet();
    if (values.isNotEmpty) {
      return values;
    }
    return {booking.bookingDate.weekday};
  }

  int? _weekdayNumberFromLabel(String value) {
    final text = value.toLowerCase().trim();
    final apiDay = int.tryParse(text);
    if (apiDay != null) {
      return switch (apiDay) {
        1 => DateTime.sunday,
        2 => DateTime.monday,
        3 => DateTime.tuesday,
        4 => DateTime.wednesday,
        5 => DateTime.thursday,
        6 => DateTime.friday,
        7 => DateTime.saturday,
        _ => null,
      };
    }
    if (text == 'cn' ||
        text.contains('chủ nhật') ||
        text.contains('chu nhat')) {
      return DateTime.sunday;
    }
    if (text.contains('2') || text.contains('hai')) {
      return DateTime.monday;
    }
    if (text.contains('3') || text.contains('ba')) {
      return DateTime.tuesday;
    }
    if (text.contains('4') || text.contains('tư') || text.contains('tu')) {
      return DateTime.wednesday;
    }
    if (text.contains('5') || text.contains('năm') || text.contains('nam')) {
      return DateTime.thursday;
    }
    if (text.contains('6') || text.contains('sáu') || text.contains('sau')) {
      return DateTime.friday;
    }
    if (text.contains('7') || text.contains('bảy') || text.contains('bay')) {
      return DateTime.saturday;
    }
    return null;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return 'Không rõ';
    }
  }

  String _minuteText(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isCancelled(OrderStatus status) {
    return status == OrderStatus.cancelled ||
        status == OrderStatus.cancelledByUserFixed ||
        status == OrderStatus.refundPending ||
        status == OrderStatus.noShow;
  }

  String _requireCurrentUserId() {
    final user = _authRepository.currentUser;
    if (user == null || user.uid.isEmpty || user.isAnonymous) {
      Get.offAllNamed(AppRoutes.login);
      throw StateError('Authenticated user is required.');
    }

    return user.uid;
  }
}
