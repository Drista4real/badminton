import 'model_json_helper.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    this.createdAt,
    this.orderId,
    this.bookingId,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? orderId;
  final String? bookingId;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: ModelJsonHelper.dateTimeFromJson(json['createdAt']),
      orderId: json['orderId'] as String?,
      bookingId: json['bookingId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'isRead': isRead,
      'createdAt': createdAt,
      'orderId': orderId,
      'bookingId': bookingId,
    };
  }
}
