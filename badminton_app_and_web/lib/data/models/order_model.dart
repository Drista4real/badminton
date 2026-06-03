import '../../constants/enums/app_enums.dart';
import 'model_json_helper.dart';

class OrderModel {
  final String id;
  final String userId;
  final List<String> bookingIds;
  final String? vietQrCode;
  final String? vietQrImageUrl;
  final String? paymentContent;
  final double totalAmount;
  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderModel({
    required this.id,
    required this.userId,
    this.bookingIds = const <String>[],
    this.vietQrCode,
    this.vietQrImageUrl,
    this.paymentContent,
    this.totalAmount = 0,
    this.orderStatus = OrderStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    this.expiresAt,
    this.paidAt,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      bookingIds: ModelJsonHelper.stringListFromJson(json['bookingIds']),
      vietQrCode: json['vietQrCode'] as String?,
      vietQrImageUrl: json['vietQrImageUrl'] as String?,
      paymentContent: json['paymentContent'] as String?,
      totalAmount: ModelJsonHelper.doubleFromJson(json['totalAmount']),
      orderStatus: OrderStatus.fromValue(json['orderStatus'] as String?),
      paymentStatus: PaymentStatus.fromValue(json['paymentStatus'] as String?),
      expiresAt: ModelJsonHelper.dateTimeFromJson(json['expiresAt']),
      paidAt: ModelJsonHelper.dateTimeFromJson(json['paidAt']),
      cancelledAt: ModelJsonHelper.dateTimeFromJson(json['cancelledAt']),
      createdAt: ModelJsonHelper.dateTimeFromJson(json['createdAt']),
      updatedAt: ModelJsonHelper.dateTimeFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bookingIds': bookingIds,
      'vietQrCode': vietQrCode,
      'vietQrImageUrl': vietQrImageUrl,
      'paymentContent': paymentContent,
      'totalAmount': totalAmount,
      'orderStatus': orderStatus.value,
      'paymentStatus': paymentStatus.value,
      'expiresAt': expiresAt,
      'paidAt': paidAt,
      'cancelledAt': cancelledAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  OrderModel copyWith({
    String? id,
    String? userId,
    List<String>? bookingIds,
    String? vietQrCode,
    String? vietQrImageUrl,
    String? paymentContent,
    double? totalAmount,
    OrderStatus? orderStatus,
    PaymentStatus? paymentStatus,
    DateTime? expiresAt,
    DateTime? paidAt,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookingIds: bookingIds ?? this.bookingIds,
      vietQrCode: vietQrCode ?? this.vietQrCode,
      vietQrImageUrl: vietQrImageUrl ?? this.vietQrImageUrl,
      paymentContent: paymentContent ?? this.paymentContent,
      totalAmount: totalAmount ?? this.totalAmount,
      orderStatus: orderStatus ?? this.orderStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      expiresAt: expiresAt ?? this.expiresAt,
      paidAt: paidAt ?? this.paidAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
