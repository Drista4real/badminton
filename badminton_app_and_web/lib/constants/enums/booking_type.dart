enum BookingType {
  oneTime,
  fixed;

  String get value {
    switch (this) {
      case BookingType.oneTime:
        return 'oneTime';
      case BookingType.fixed:
        return 'fixed';
    }
  }

  static BookingType fromValue(String? value) {
    switch (value) {
      case 'fixed':
        return BookingType.fixed;
      case 'oneTime':
      default:
        return BookingType.oneTime;
    }
  }
}
