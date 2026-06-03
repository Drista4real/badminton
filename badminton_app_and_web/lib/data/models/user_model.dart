import 'model_json_helper.dart';

class UserModel {
  final String id;
  final String email;
  final String? phoneNumber;
  final String fullName;
  final String? avatarUrl;
  final int loyaltyPoints;
  final double walletBalance;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.phoneNumber,
    required this.fullName,
    this.avatarUrl,
    this.loyaltyPoints = 0,
    this.walletBalance = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      fullName: json['fullName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      loyaltyPoints: ModelJsonHelper.intFromJson(json['loyaltyPoints']),
      walletBalance: ModelJsonHelper.doubleFromJson(json['walletBalance']),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: ModelJsonHelper.dateTimeFromJson(json['createdAt']),
      updatedAt: ModelJsonHelper.dateTimeFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'loyaltyPoints': loyaltyPoints,
      'walletBalance': walletBalance,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? fullName,
    String? avatarUrl,
    int? loyaltyPoints,
    double? walletBalance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      walletBalance: walletBalance ?? this.walletBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
