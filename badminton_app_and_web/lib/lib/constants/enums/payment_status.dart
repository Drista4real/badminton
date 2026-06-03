enum PaymentStatus {
  pending,
  success,
  expired,
  cancelled,
  refunded;

  String get value {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.success:
        return 'success';
      case PaymentStatus.expired:
        return 'expired';
      case PaymentStatus.cancelled:
        return 'cancelled';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }

  static PaymentStatus fromValue(String? value) {
    switch (value) {
      case 'success':
        return PaymentStatus.success;
      case 'expired':
        return PaymentStatus.expired;
      case 'cancelled':
        return PaymentStatus.cancelled;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }
}
