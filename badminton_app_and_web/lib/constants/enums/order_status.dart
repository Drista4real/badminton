enum OrderStatus {
  pending,
  confirmed,
  paid,
  completed,
  cancelled,
  cancelledByUserFixed;

  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.paid:
        return 'paid';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.cancelledByUserFixed:
        return 'Cancelled_By_User_Fixed';
    }
  }

  static OrderStatus fromValue(String? value) {
    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'paid':
        return OrderStatus.paid;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'Cancelled_By_User_Fixed':
      case 'cancelled_by_user_fixed':
        return OrderStatus.cancelledByUserFixed;
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }
}
