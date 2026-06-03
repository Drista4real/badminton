import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commons/styles/app_colors.dart';
import '../../commons/widgets/custom_button.dart';
import '../../constants/enums/app_enums.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../data/repository/booking_repository.dart';
import '../../data/repository/court_repository.dart';
import '../../routes/app_routes.dart';
import '../../utils/currency_format.dart';
import '../../utils/date_format.dart';

class BookingController extends GetxController {
  BookingController({
    required CourtRepository courtRepository,
    required BookingRepository bookingRepository,
  }) : _courtRepository = courtRepository,
       _bookingRepository = bookingRepository;

  static const minBookingHour = 5.0;
  static const maxBookingHour = 24.0;
  static const minTimelineScale = 0.0;
  static const maxTimelineScale = 1.0;
  static const compactHourCellWidth = 42.0;
  static const expandedHourCellWidth = 92.0;
  static const minutesPerHour = 60;
  static const slotMinutes = 30;
  static const minBookingMinutes = 5 * minutesPerHour;
  static const maxBookingMinutes = 24 * minutesPerHour;
  static const _weekdayPriceBands = <_PriceBand>[
    _PriceBand(5 * minutesPerHour, 9 * minutesPerHour, 'weekday.morning'),
    _PriceBand(9 * minutesPerHour, 16 * minutesPerHour, 'weekday.base'),
    _PriceBand(16 * minutesPerHour, 22 * minutesPerHour, 'weekday.peak'),
    _PriceBand(22 * minutesPerHour, 24 * minutesPerHour, 'late'),
  ];
  static const _weekendPriceBands = <_PriceBand>[
    _PriceBand(5 * minutesPerHour, 16 * minutesPerHour, 'weekend.base'),
    _PriceBand(16 * minutesPerHour, 22 * minutesPerHour, 'weekend.peak'),
    _PriceBand(22 * minutesPerHour, 24 * minutesPerHour, 'late'),
  ];

  final CourtRepository _courtRepository;
  final BookingRepository _bookingRepository;

  StreamSubscription<List<BookingModel>>? _bookingsSub;

  final selectedDate = DateTime.now().obs;
  final startHour = minBookingHour.obs;
  final endHour = maxBookingHour.obs;
  final timelineScale = minTimelineScale.obs;
  final matType = 'PVC'.obs;

  final isLoadingCourts = true.obs;
  final isLoadingBookings = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;
  final bookingScheduleError = ''.obs;
  final courts = <CourtModel>[].obs;
  final activeBookings = <BookingModel>[].obs;
  final selectedSlotKeys = <String>{}.obs;

  final timeSlots = List<int>.generate(
    (maxBookingMinutes - minBookingMinutes) ~/ slotMinutes,
    (index) => minBookingMinutes + index * slotMinutes,
  ).obs;
  final weekdays = <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].obs;
  final selectedWeekdays = <String>{}.obs;
  final fixedStart = 18.0.obs;
  final fixedEnd = 20.0.obs;
  final months = 3.obs;
  final selectedFixedCourtIds = <String>{}.obs;
  final showSummary = true.obs;

  @override
  void onInit() {
    super.onInit();
    refreshCourts();
    _watchBookings();
  }

  Future<void> refreshCourts() async {
    isLoadingCourts.value = true;
    errorMessage.value = '';

    try {
      final items = await _courtRepository.fetchActiveCourts();
      courts.assignAll(items);
      selectedFixedCourtIds.removeWhere(
        (courtId) => !items.any((court) => court.id == courtId),
      );
      selectedSlotKeys.removeWhere((key) {
        final slot = _slotFromKey(key);
        return slot == null || slot.courtIndex >= items.length;
      });
      selectedSlotKeys.refresh();
    } on CourtApiException catch (error) {
      courts.clear();
      selectedFixedCourtIds.clear();
      selectedSlotKeys.clear();
      errorMessage.value = error.message;
    } catch (_) {
      courts.clear();
      selectedFixedCourtIds.clear();
      selectedSlotKeys.clear();
      errorMessage.value = 'Không tải được danh sách sân từ backend.';
    } finally {
      isLoadingCourts.value = false;
    }
  }

  void _watchBookings() {
    isLoadingBookings.value = true;
    bookingScheduleError.value = '';

    _bookingsSub = _bookingRepository.watchActiveBookings().listen(
      (items) {
        activeBookings.assignAll(items);
        isLoadingBookings.value = false;
        bookingScheduleError.value = '';
      },
      onError: (_) {
        activeBookings.clear();
        selectedSlotKeys.clear();
        selectedSlotKeys.refresh();
        isLoadingBookings.value = false;
        bookingScheduleError.value = 'Không tải được lịch đặt sân.';
        errorMessage.value = 'Không tải được lịch đặt sân.';
      },
    );
  }

  String formatHour(double hour) => formatMinutes(_hourValueToMinutes(hour));

  String formatMinutes(int minutes) {
    return '${(minutes ~/ minutesPerHour).toString().padLeft(2, '0')}:${(minutes % minutesPerHour).toString().padLeft(2, '0')}';
  }

  String get selectedDateLabel {
    return DateFormatUtils.dayMonthYear(selectedDate.value);
  }

  int get startIndex {
    return ((startMinute - minBookingMinutes) ~/ slotMinutes).clamp(
      0,
      timeSlots.length - 1,
    );
  }

  int get endIndex {
    return ((endMinute - minBookingMinutes) ~/ slotMinutes).clamp(
      startIndex + 1,
      timeSlots.length,
    );
  }

  int get startMinute => _hourValueToMinutes(startHour.value);

  int get endMinute => _hourValueToMinutes(endHour.value);

  List<int> get visibleSlotStarts => timeSlots.sublist(startIndex, endIndex);

  double get timeGridCellWidth {
    final normalizedScale = timelineScale.value.clamp(
      minTimelineScale,
      maxTimelineScale,
    );
    return compactHourCellWidth +
        (expandedHourCellWidth - compactHourCellWidth) * normalizedScale;
  }

  String courtCodeAt(int courtIndex) {
    final court = courts[courtIndex];
    if (court.code.isNotEmpty) return court.code;
    if (court.name.isNotEmpty) return court.name;
    return court.id;
  }

  String courtName(CourtModel court) {
    if (court.name.isNotEmpty) return court.name;
    if (court.code.isNotEmpty) return 'Sân ${court.code}';
    return court.id;
  }

  String formatMoney(num amount) => CurrencyFormat.vnd(amount);

  String formatBookingRange(int startTime, int endTime) {
    return '${formatMinutes(startTime)} - ${formatMinutes(endTime)}';
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ minutesPerHour;
    final remainder = minutes % minutesPerHour;
    if (hours == 0) return '${remainder}p';
    if (remainder == 0) return '${hours}h';
    return '${hours}h${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setSelectedDate(picked);
    }
  }

  void showTimeRangeSheet(BuildContext context) {
    var tempRange = RangeValues(startHour.value, endHour.value);

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chọn khung giờ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                Text(
                  '${formatHour(tempRange.start)} - ${formatHour(tempRange.end)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                RangeSlider(
                  values: tempRange,
                  min: minBookingHour,
                  max: maxBookingHour,
                  divisions:
                      (maxBookingMinutes - minBookingMinutes) ~/ slotMinutes,
                  activeColor: AppColors.primary,
                  inactiveColor: const Color(0xFFEEEEEE),
                  onChanged: (value) {
                    setSheetState(() => tempRange = _normalizeRange(value));
                  },
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Áp dụng',
                  onTap: () {
                    setTimeRange(tempRange.start, tempRange.end);
                    Get.back<void>();
                  },
                ),
              ],
            ),
          );
        },
      ),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  void showOneTimeConfirmSheet(BuildContext context) {
    Get.bottomSheet<void>(
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Sân ${selectedCourtNumbers.join(', ')}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Trống',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BookingConfirmRow('Loại thảm', matType.value),
              _BookingConfirmRow(
                'Thời gian',
                formatBookingRange(selectedStartTime, selectedEndTime),
              ),
              _BookingConfirmRow('Ngày đặt', selectedDateLabel),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng tiền tạm tính',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  Text(
                    formatMoney(totalPrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: isSubmitting.value ? 'Đang tạo đơn...' : 'Xác nhận',
                onTap: isSubmitting.value
                    ? () {}
                    : () async {
                        Get.back<void>();
                        await submitOneTimeBooking();
                      },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  void showFixedTimePickerSheet(BuildContext context, {required bool isStart}) {
    var tempHour = isStart ? fixedStart.value : fixedEnd.value;
    final minDuration = slotMinutes / minutesPerHour;
    final minHour = isStart ? minBookingHour : minBookingHour + minDuration;
    final maxHour = isStart ? maxBookingHour - minDuration : maxBookingHour;
    tempHour = tempHour.clamp(minHour, maxHour).toDouble();

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isStart ? 'Giờ bắt đầu' : 'Giờ kết thúc',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  formatHour(tempHour),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Slider(
                  value: tempHour,
                  min: minHour,
                  max: maxHour,
                  divisions:
                      ((maxHour - minHour) * minutesPerHour / slotMinutes)
                          .round(),
                  activeColor: AppColors.primary,
                  inactiveColor: const Color(0xFFEEEEEE),
                  onChanged: (value) {
                    setSheetState(() => tempHour = value);
                  },
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Áp dụng',
                  onTap: () {
                    setFixedTime(isStart: isStart, hour: tempHour);
                    Get.back<void>();
                  },
                ),
              ],
            ),
          );
        },
      ),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  bool isSlotSelected(int courtIndex, int slotIndex) {
    return selectedSlotKeys.contains(slotKey(courtIndex, slotIndex));
  }

  String slotKey(int courtIndex, int slotIndex) {
    return '${courtIndex}_$slotIndex';
  }

  BookingSlotStatus slotStatus(int courtIndex, int slotIndex) {
    if (courtIndex < 0 || courtIndex >= courts.length) {
      return BookingSlotStatus.booked;
    }
    if (slotIndex < 0 || slotIndex >= timeSlots.length) {
      return BookingSlotStatus.booked;
    }

    final slotStart = timeSlots[slotIndex];
    final slotEnd = slotStart + slotMinutes;
    if (_isPastSlot(selectedDate.value, slotStart)) {
      return BookingSlotStatus.past;
    }

    final court = courts[courtIndex];
    var fallback = BookingSlotStatus.available;

    for (final booking in materializedBookingsForDate(selectedDate.value)) {
      if (!_materializedBookingUsesCourt(booking, court)) continue;
      if (!_overlaps(slotStart, slotEnd, booking.startTime, booking.endTime)) {
        continue;
      }

      final status = _slotStatusForBooking(booking);
      if (status == BookingSlotStatus.pending ||
          status == BookingSlotStatus.fixed) {
        return status;
      }
      fallback = status;
    }

    return fallback;
  }

  bool canSelectSlot(int courtIndex, int slotIndex) {
    if (isLoadingBookings.value || bookingScheduleError.value.isNotEmpty) {
      return false;
    }

    return slotStatus(courtIndex, slotIndex) == BookingSlotStatus.available;
  }

  void toggleSlot(int courtIndex, int slotIndex) {
    if (!canSelectSlot(courtIndex, slotIndex)) return;

    final key = slotKey(courtIndex, slotIndex);
    if (selectedSlotKeys.contains(key)) {
      selectedSlotKeys.remove(key);
    } else {
      selectedSlotKeys.add(key);
    }
    selectedSlotKeys.refresh();
  }

  void clearSelectedSlots() {
    selectedSlotKeys.clear();
    selectedSlotKeys.refresh();
  }

  void _clearOneTimeDraft() {
    clearSelectedSlots();
  }

  void _clearFixedDraft() {
    selectedFixedCourtIds.clear();
    selectedFixedCourtIds.refresh();
    selectedWeekdays.clear();
    selectedWeekdays.refresh();
    showSummary.value = true;
  }

  void setSelectedDate(DateTime value) {
    selectedDate.value = value;
    clearSelectedSlots();
  }

  void decreaseStartHour() {
    if (startHour.value <= minBookingHour) return;
    startHour.value -= slotMinutes / minutesPerHour;
    clearSelectedSlots();
  }

  void increaseEndHour() {
    if (endHour.value >= maxBookingHour) return;
    endHour.value += slotMinutes / minutesPerHour;
    clearSelectedSlots();
  }

  void setTimeRange(double start, double end) {
    final range = _normalizeRange(RangeValues(start, end));
    startHour.value = range.start;
    endHour.value = range.end;
    clearSelectedSlots();
  }

  void setTimelineScale(double value) {
    timelineScale.value = value
        .clamp(minTimelineScale, maxTimelineScale)
        .toDouble();
  }

  List<BookingSlotSelection> get selectedSlots {
    final slots = <BookingSlotSelection>[];
    for (final key in selectedSlotKeys) {
      final slot = _slotFromKey(key);
      if (slot != null && slot.courtIndex < courts.length) {
        slots.add(slot);
      }
    }
    slots.sort((a, b) {
      final courtCompare = a.courtIndex.compareTo(b.courtIndex);
      return courtCompare == 0
          ? a.slotIndex.compareTo(b.slotIndex)
          : courtCompare;
    });
    return slots;
  }

  List<String> get selectedCourtNumbers {
    final courtNumbers = selectedSlots
        .map((slot) => courtCodeAt(slot.courtIndex))
        .toSet()
        .toList();
    courtNumbers.sort();
    return courtNumbers;
  }

  List<int> get selectedSlotStarts {
    final selected = selectedSlots
        .map((slot) => timeSlots[slot.slotIndex])
        .toList();
    selected.sort();
    return selected;
  }

  int get selectedStartTime =>
      selectedSlotStarts.isEmpty ? 0 : selectedSlotStarts.first;

  int get selectedEndTime =>
      selectedSlotStarts.isEmpty ? 0 : selectedSlotStarts.last + slotMinutes;

  int get selectedDurationMinutes => selectedSlots.length * slotMinutes;

  double get totalPrice {
    var total = 0.0;
    for (final slot in selectedSlots) {
      if (slot.courtIndex < 0 || slot.courtIndex >= courts.length) continue;
      final startMinutes = timeSlots[slot.slotIndex];
      total += _priceForRange(
        court: courts[slot.courtIndex],
        date: selectedDate.value,
        startMinutes: startMinutes,
        endMinutes: startMinutes + slotMinutes,
        customerType: _PriceCustomerType.account,
      );
    }
    return total;
  }

  Future<void> submitOneTimeBooking() async {
    if (selectedSlots.isEmpty || isSubmitting.value) return;

    final request = _selectedApiBookingRequest();
    if (request == null) {
      Get.snackbar(
        'Không thể đặt sân',
        'Vui lòng chọn các khung giờ liên tiếp trên cùng một sân.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSubmitting.value = true;
    errorMessage.value = '';

    try {
      final result = await _bookingRepository.createBookingViaApi(
        courtId: request.courtId,
        date: selectedDate.value,
        startTime: request.startTime,
        endTime: request.endTime,
        totalPrice: request.totalPrice,
      );

      final paymentArguments = {
        'orderId': result.orderId,
        'bookingIds': result.bookingIds,
        'courtName': 'Sân ${courtCodeAt(request.courtIndex)}',
        'price': result.totalPrice,
        'date': selectedDateLabel,
        'time': formatBookingRange(request.startTime, request.endTime),
        'isFixed': false,
      };

      _clearOneTimeDraft();
      Get.toNamed(AppRoutes.payment, arguments: paymentArguments);
    } on BookingConflictException {
      await refreshActiveBookings();
      errorMessage.value = 'Sân đã có người đặt, vui lòng chọn giờ khác.';
      Get.snackbar(
        'Không thể đặt sân',
        'Sân đã có người đặt, vui lòng chọn giờ khác',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on BookingApiException catch (error) {
      errorMessage.value = error.message;
      debugPrint('Create booking failed: $error');
      Get.snackbar(
        'Không thể đặt sân',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      errorMessage.value = 'Không thể tạo đơn đặt sân.';
      debugPrint('Create booking failed: $error');
    } finally {
      isSubmitting.value = false;
    }
  }

  void toggleWeekday(String day) {
    if (selectedWeekdays.contains(day)) {
      selectedWeekdays.remove(day);
    } else {
      selectedWeekdays.add(day);
    }
    selectedWeekdays.refresh();
  }

  void setMonths(int value) {
    months.value = value;
  }

  List<CourtModel> get availableFixedCourts {
    final fixedDates = _selectedFixedDates.toList();
    if (fixedDates.isEmpty) return courts.toList();
    final fixedStartTime = _hourValueToMinutes(fixedStart.value);
    final fixedEndTime = _hourValueToMinutes(fixedEnd.value);

    return courts.where((court) {
      for (final date in fixedDates) {
        for (final booking in materializedBookingsForDate(date)) {
          if (!_materializedBookingUsesCourt(booking, court)) continue;
          if (_overlaps(
            fixedStartTime,
            fixedEndTime,
            booking.startTime,
            booking.endTime,
          )) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  void toggleAllFixedCourts() {
    final availableIds = availableFixedCourts.map((court) => court.id).toSet();
    if (selectedFixedCourtIds.length == availableIds.length) {
      selectedFixedCourtIds.clear();
    } else {
      selectedFixedCourtIds
        ..clear()
        ..addAll(availableIds);
    }
    selectedFixedCourtIds.refresh();
  }

  void toggleFixedCourt(String courtId) {
    if (selectedFixedCourtIds.contains(courtId)) {
      selectedFixedCourtIds.remove(courtId);
    } else {
      selectedFixedCourtIds.add(courtId);
    }
    selectedFixedCourtIds.refresh();
  }

  void setFixedTime({required bool isStart, required double hour}) {
    final normalizedHour = _snapHourValue(hour);
    final minDuration = slotMinutes / minutesPerHour;
    if (isStart) {
      fixedStart.value = normalizedHour
          .clamp(minBookingHour, maxBookingHour - minDuration)
          .toDouble();
      if (fixedEnd.value <= fixedStart.value) {
        fixedEnd.value = fixedStart.value + minDuration;
      }
    } else {
      fixedEnd.value = normalizedHour
          .clamp(minBookingHour + minDuration, maxBookingHour)
          .toDouble();
      if (fixedStart.value >= fixedEnd.value) {
        fixedStart.value = fixedEnd.value - minDuration;
      }
    }
    selectedFixedCourtIds.clear();
  }

  void toggleSummary() {
    showSummary.value = !showSummary.value;
  }

  double get fixedHours => fixedEnd.value - fixedStart.value;

  int get fixedSessionPriceInThousands {
    final courtCount = selectedFixedCourtIds.length;
    if (fixedSessionCount <= 0 || courtCount <= 0) return 0;
    return (fixedTotal / fixedSessionCount / courtCount / 1000).round();
  }

  bool get canShowFixedSummary {
    return selectedFixedCourtIds.isNotEmpty && selectedWeekdays.isNotEmpty;
  }

  int get fixedSessionCount {
    return _selectedFixedDates.length;
  }

  double get fixedTotal {
    var total = 0.0;
    final selectedDates = _selectedFixedDates.toList();
    final startMinutes = _hourValueToMinutes(fixedStart.value);
    final endMinutes = _hourValueToMinutes(fixedEnd.value);

    for (final court in courts) {
      if (!selectedFixedCourtIds.contains(court.id)) continue;
      for (final date in selectedDates) {
        total += _priceForRange(
          court: court,
          date: date,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          customerType: _PriceCustomerType.fixed,
        );
      }
    }

    return total;
  }

  String get selectedWeekdaysLabel => selectedWeekdays.join(', ');

  String get selectedFixedCourtNames {
    return courts
        .where((court) => selectedFixedCourtIds.contains(court.id))
        .map(courtName)
        .join(', ');
  }

  Future<void> submitFixedBooking() async {
    if (!canShowFixedSummary || isSubmitting.value) return;

    if (!const {1, 3, 6}.contains(months.value)) {
      errorMessage.value = 'Kỳ hạn lịch cố định chỉ hỗ trợ 1, 3 hoặc 6 tháng.';
      Get.snackbar(
        'Không thể đặt lịch',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (selectedFixedCourtIds.length != 1) {
      errorMessage.value =
          'API lịch cố định hiện chỉ nhận một sân mỗi lần đặt. Vui lòng chọn 1 sân.';
      Get.snackbar(
        'Không thể đặt lịch',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final courtId = selectedFixedCourtIds.first;
    final court = courts.firstWhereOrNull((item) => item.id == courtId);
    final startDate = _dateOnly(DateTime.now());
    final fixedDays = _selectedFixedDayNumbers();

    if (fixedDays.isEmpty) {
      errorMessage.value = 'Vui lòng chọn ngày trong tuần.';
      return;
    }

    isSubmitting.value = true;
    errorMessage.value = '';

    try {
      final result = await _bookingRepository.createFixedBookingViaApi(
        courtId: courtId,
        startDate: startDate,
        months: months.value,
        daysOfWeek: fixedDays,
        startTime: _hourValueToMinutes(fixedStart.value),
        endTime: _hourValueToMinutes(fixedEnd.value),
        totalPrice: fixedTotal,
      );

      final paymentArguments = {
        'orderId': result.orderId,
        'bookingIds': result.bookingIds,
        'courtName': court == null ? courtId : courtName(court),
        'price': result.totalPrice,
        'date':
            'Từ ${DateFormatUtils.dayMonthYear(startDate)} - ${months.value} tháng',
        'time':
            '${formatHour(fixedStart.value)} - ${formatHour(fixedEnd.value)}',
        'isFixed': true,
        'fixedDuration': '${months.value} tháng',
      };

      _clearFixedDraft();
      Get.toNamed(AppRoutes.payment, arguments: paymentArguments);
    } on BookingConflictException {
      await refreshActiveBookings();
      errorMessage.value =
          'Một hoặc nhiều buổi trong lịch cố định đã có người đặt.';
      Get.snackbar(
        'Trùng lịch',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on BookingApiException catch (error) {
      errorMessage.value = error.message;
      debugPrint('Create fixed booking failed: $error');
      Get.snackbar(
        'Không thể đặt lịch',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      errorMessage.value = 'Không thể tạo đơn lịch cố định. Vui lòng thử lại.';
      debugPrint('Create fixed booking failed: $error');
      Get.snackbar(
        'Không thể đặt lịch',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> refreshActiveBookings() async {
    try {
      final bookings = await _bookingRepository.fetchActiveBookings();
      activeBookings.assignAll(bookings);
      bookingScheduleError.value = '';
      selectedSlotKeys.removeWhere((key) {
        final slot = _slotFromKey(key);
        return slot == null ||
            slot.courtIndex >= courts.length ||
            !canSelectSlot(slot.courtIndex, slot.slotIndex);
      });
      selectedSlotKeys.refresh();
    } catch (_) {
      activeBookings.clear();
      selectedSlotKeys.clear();
      selectedSlotKeys.refresh();
      bookingScheduleError.value = 'Không tải được lịch đặt sân mới nhất.';
      errorMessage.value = 'Không tải được lịch đặt sân mới nhất.';
    }
  }

  List<MaterializedBookingSlot> materializedBookingsForDate(DateTime date) {
    final materialized = <MaterializedBookingSlot>[];
    for (final booking in activeBookings) {
      if (!_bookingAppliesToDate(booking, date)) continue;
      materialized.add(
        MaterializedBookingSlot(
          source: booking,
          date: _dateOnly(date),
          startTime: booking.startTime,
          endTime: booking.endTime,
        ),
      );
    }
    return materialized;
  }

  BookingSlotSelection? _slotFromKey(String key) {
    final parts = key.split('_');
    if (parts.length != 2) return null;
    final courtIndex = int.tryParse(parts[0]);
    final slotIndex = int.tryParse(parts[1]);
    if (courtIndex == null || slotIndex == null) return null;
    return BookingSlotSelection(courtIndex: courtIndex, slotIndex: slotIndex);
  }

  bool _bookingUsesCourt(BookingModel booking, CourtModel court) {
    return booking.courtId == court.id ||
        booking.courtId == court.code ||
        booking.courtId == court.name;
  }

  bool _materializedBookingUsesCourt(
    MaterializedBookingSlot booking,
    CourtModel court,
  ) {
    return _bookingUsesCourt(booking.source, court);
  }

  bool _bookingAppliesToDate(BookingModel booking, DateTime date) {
    if (booking.bookingType == BookingType.oneTime) {
      return _sameDate(booking.bookingDate, date);
    }

    return _fixedBookingOccursOnDate(booking, date);
  }

  bool _fixedBookingOccursOnDate(BookingModel booking, DateTime date) {
    final normalizedDate = _dateOnly(date);
    final startDate = _dateOnly(booking.fixedStartDate ?? booking.bookingDate);
    final endDate = _dateOnly(booking.fixedEndDate ?? booking.bookingDate);

    if (normalizedDate.isBefore(startDate) || normalizedDate.isAfter(endDate)) {
      return false;
    }

    if (booking.fixedWeekdays.isEmpty) {
      return _sameDate(booking.bookingDate, date);
    }

    return booking.fixedWeekdays.any(
      (weekday) => _fixedWeekdayMatchesDate(weekday, date),
    );
  }

  Iterable<DateTime> get _selectedFixedDates sync* {
    final selected = selectedWeekdays.toSet();
    if (selected.isEmpty) return;

    final startDate = _dateOnly(DateTime.now());
    final endDate = DateTime(
      startDate.year,
      startDate.month + months.value,
      startDate.day,
    );

    var cursor = startDate;
    while (cursor.isBefore(endDate)) {
      if (selected.contains(_weekdayLabelForDate(cursor))) {
        yield cursor;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  BookingSlotStatus _slotStatusForBooking(MaterializedBookingSlot booking) {
    if (booking.source.status == OrderStatus.pending) {
      return BookingSlotStatus.pending;
    }

    if (booking.source.bookingType == BookingType.fixed) {
      return BookingSlotStatus.fixed;
    }

    return BookingSlotStatus.booked;
  }

  SelectedApiBookingRequest? _selectedApiBookingRequest() {
    final slots = selectedSlots;
    if (slots.isEmpty) return null;

    final courtIndex = slots.first.courtIndex;
    if (slots.any((slot) => slot.courtIndex != courtIndex)) {
      return null;
    }

    for (var index = 1; index < slots.length; index++) {
      if (slots[index].slotIndex != slots[index - 1].slotIndex + 1) {
        return null;
      }
    }

    final startTime = timeSlots[slots.first.slotIndex];
    final endTime = timeSlots[slots.last.slotIndex] + slotMinutes;
    return SelectedApiBookingRequest(
      courtIndex: courtIndex,
      courtId: courts[courtIndex].id,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
    );
  }

  String _weekdayLabelForDate(DateTime date) {
    return weekdays[(date.weekday - 1).clamp(0, weekdays.length - 1)];
  }

  List<int> _selectedFixedDayNumbers() {
    final values = selectedWeekdays.map(_apiDayOfWeek).whereType<int>().toSet();
    final sorted = values.toList()..sort();
    return sorted;
  }

  int? _apiDayOfWeek(String label) {
    switch (label) {
      case 'T2':
        return 2;
      case 'T3':
        return 3;
      case 'T4':
        return 4;
      case 'T5':
        return 5;
      case 'T6':
        return 6;
      case 'T7':
        return 7;
      case 'CN':
        return 1;
      default:
        return null;
    }
  }

  bool _fixedWeekdayMatchesDate(String value, DateTime date) {
    final apiDay = int.tryParse(value.trim());
    if (apiDay != null) {
      return _dateWeekdayFromApiDay(apiDay) == date.weekday;
    }

    return value == _weekdayLabelForDate(date);
  }

  int? _dateWeekdayFromApiDay(int apiDay) {
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

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _sameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  bool _overlaps(int start, int end, int otherStart, int otherEnd) {
    return start < otherEnd && otherStart < end;
  }

  bool _isPastSlot(DateTime date, int startMinutes) {
    final now = DateTime.now();
    final slot = DateTime(
      date.year,
      date.month,
      date.day,
      startMinutes ~/ minutesPerHour,
      startMinutes % minutesPerHour,
    );
    return slot.isBefore(now);
  }

  static int _hourValueToMinutes(double hour) {
    return (hour * minutesPerHour).round();
  }

  static double _minutesToHourValue(int minutes) {
    return minutes / minutesPerHour;
  }

  static double _snapHourValue(double hour) {
    final minutes = _hourValueToMinutes(
      hour,
    ).clamp(minBookingMinutes, maxBookingMinutes).toInt();
    final snappedMinutes = (minutes / slotMinutes).round() * slotMinutes;
    return _minutesToHourValue(
      snappedMinutes.clamp(minBookingMinutes, maxBookingMinutes).toInt(),
    );
  }

  static RangeValues _normalizeRange(RangeValues range) {
    var startMinutes = _hourValueToMinutes(_snapHourValue(range.start));
    var endMinutes = _hourValueToMinutes(_snapHourValue(range.end));

    if (endMinutes - startMinutes < slotMinutes) {
      if (startMinutes + slotMinutes <= maxBookingMinutes) {
        endMinutes = startMinutes + slotMinutes;
      } else {
        startMinutes = endMinutes - slotMinutes;
      }
    }

    return RangeValues(
      _minutesToHourValue(startMinutes),
      _minutesToHourValue(endMinutes),
    );
  }

  double _priceForRange({
    required CourtModel court,
    required DateTime date,
    required int startMinutes,
    required int endMinutes,
    required _PriceCustomerType customerType,
  }) {
    var coveredMinutes = 0;
    var total = 0.0;

    for (final band in _priceBandsForDate(date)) {
      final overlapStart = startMinutes > band.startMinutes
          ? startMinutes
          : band.startMinutes;
      final overlapEnd = endMinutes < band.endMinutes
          ? endMinutes
          : band.endMinutes;
      if (overlapStart >= overlapEnd) continue;

      final hourlyRate = _priceByKey(
        court,
        '${band.priceKeyPrefix}.${_priceCustomerKey(customerType)}',
      );
      if (hourlyRate <= 0) return 0;

      final minutes = overlapEnd - overlapStart;
      total += hourlyRate * minutes / minutesPerHour;
      coveredMinutes += minutes;
    }

    return coveredMinutes == endMinutes - startMinutes
        ? total.roundToDouble()
        : 0;
  }

  List<_PriceBand> _priceBandsForDate(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday
        ? _weekendPriceBands
        : _weekdayPriceBands;
  }

  double _priceByKey(CourtModel court, String key) {
    final value = court.hourlyPrices[key];
    return value == null || value <= 0 ? 0 : value;
  }

  String _priceCustomerKey(_PriceCustomerType customerType) {
    switch (customerType) {
      case _PriceCustomerType.guest:
        return 'guest';
      case _PriceCustomerType.account:
        return 'account';
      case _PriceCustomerType.fixed:
        return 'fixed';
    }
  }

  @override
  void onClose() {
    _bookingsSub?.cancel();
    super.onClose();
  }
}

class _BookingConfirmRow extends StatelessWidget {
  const _BookingConfirmRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.grey),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
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

enum BookingSlotStatus { available, selected, booked, pending, fixed, past }

class BookingSlotSelection {
  const BookingSlotSelection({
    required this.courtIndex,
    required this.slotIndex,
  });

  final int courtIndex;
  final int slotIndex;
}

class MaterializedBookingSlot {
  const MaterializedBookingSlot({
    required this.source,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  final BookingModel source;
  final DateTime date;
  final int startTime;
  final int endTime;
}

class SelectedApiBookingRequest {
  const SelectedApiBookingRequest({
    required this.courtIndex,
    required this.courtId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
  });

  final int courtIndex;
  final String courtId;
  final int startTime;
  final int endTime;
  final double totalPrice;
}

enum _PriceCustomerType { guest, account, fixed }

class _PriceBand {
  const _PriceBand(this.startMinutes, this.endMinutes, this.priceKeyPrefix);

  final int startMinutes;
  final int endMinutes;
  final String priceKeyPrefix;
}
