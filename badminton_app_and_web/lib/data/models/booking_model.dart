import '../../constants/enums/app_enums.dart';
import 'model_json_helper.dart';

class BookingModel {
  final String id;
  final String userId;
  final String courtId;
  final String? orderId;
  final BookingType bookingType;
  final OrderStatus status;
  final DateTime bookingDate;
  final int startTime;
  final int endTime;
  final double totalPrice;
  final List<String> fixedWeekdays;
  final int? fixedDurationMonths;
  final DateTime? fixedStartDate;
  final DateTime? fixedEndDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.courtId,
    this.orderId,
    this.bookingType = BookingType.oneTime,
    this.status = OrderStatus.pending,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.totalPrice = 0,
    this.fixedWeekdays = const <String>[],
    this.fixedDurationMonths,
    this.fixedStartDate,
    this.fixedEndDate,
    this.createdAt,
    this.updatedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      courtId: json['courtId'] as String? ?? '',
      orderId: json['orderId'] as String?,
      bookingType: BookingType.fromValue(json['bookingType'] as String?),
      status: OrderStatus.fromValue(json['status'] as String?),
      bookingDate:
          ModelJsonHelper.dateTimeFromJson(json['bookingDate']) ??
          ModelJsonHelper.dateTimeFromJson(json['date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startTime: _startTimeFromJson(json['startTime'], json['startHour']),
      endTime: _endTimeFromJson(json['endTime'], json['endHour']),
      totalPrice: ModelJsonHelper.doubleFromJson(json['totalPrice']),
      fixedWeekdays: ModelJsonHelper.stringListFromJson(json['fixedWeekdays']),
      fixedDurationMonths: json['fixedDurationMonths'] == null
          ? null
          : ModelJsonHelper.intFromJson(json['fixedDurationMonths']),
      fixedStartDate: ModelJsonHelper.dateTimeFromJson(json['fixedStartDate']),
      fixedEndDate: ModelJsonHelper.dateTimeFromJson(json['fixedEndDate']),
      createdAt: ModelJsonHelper.dateTimeFromJson(json['createdAt']),
      updatedAt: ModelJsonHelper.dateTimeFromJson(json['updatedAt']),
    );
  }

  int get startHour => startTime ~/ 60;

  int get endHour => (endTime / 60).ceil();

  static int _startTimeFromJson(Object? minuteValue, Object? hourValue) {
    if (minuteValue != null) {
      return ModelJsonHelper.intFromJson(minuteValue);
    }

    return ModelJsonHelper.intFromJson(hourValue) * 60;
  }

  static int _endTimeFromJson(Object? minuteValue, Object? hourValue) {
    if (minuteValue != null) {
      return ModelJsonHelper.intFromJson(minuteValue);
    }

    return ModelJsonHelper.intFromJson(hourValue) * 60;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'courtId': courtId,
      'orderId': orderId,
      'bookingType': bookingType.value,
      'status': status.value,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'totalPrice': totalPrice,
      'fixedWeekdays': fixedWeekdays,
      'fixedDurationMonths': fixedDurationMonths,
      'fixedStartDate': fixedStartDate,
      'fixedEndDate': fixedEndDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  BookingModel copyWith({
    String? id,
    String? userId,
    String? courtId,
    String? orderId,
    BookingType? bookingType,
    OrderStatus? status,
    DateTime? bookingDate,
    int? startTime,
    int? endTime,
    double? totalPrice,
    List<String>? fixedWeekdays,
    int? fixedDurationMonths,
    DateTime? fixedStartDate,
    DateTime? fixedEndDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courtId: courtId ?? this.courtId,
      orderId: orderId ?? this.orderId,
      bookingType: bookingType ?? this.bookingType,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalPrice: totalPrice ?? this.totalPrice,
      fixedWeekdays: fixedWeekdays ?? this.fixedWeekdays,
      fixedDurationMonths: fixedDurationMonths ?? this.fixedDurationMonths,
      fixedStartDate: fixedStartDate ?? this.fixedStartDate,
      fixedEndDate: fixedEndDate ?? this.fixedEndDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
