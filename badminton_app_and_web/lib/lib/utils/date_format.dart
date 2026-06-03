class DateFormatUtils {
  DateFormatUtils._();

  static String dayMonthYear(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String nullableDayMonthYear(DateTime? date) {
    if (date == null) return '--/--/----';
    return dayMonthYear(date);
  }

  static String vietnameseWeekdayDate(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];

    return '${weekdays[date.weekday - 1]}, ${dayMonthYear(date)}';
  }

  static String apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

@Deprecated('Use DateFormatUtils instead.')
typedef AppDateFormat = DateFormatUtils;
