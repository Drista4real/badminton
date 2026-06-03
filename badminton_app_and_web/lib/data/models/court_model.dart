import 'model_json_helper.dart';

class CourtModel {
  final String id;
  final String name;
  final String code;
  final String surfaceType;
  final String status;
  final bool isActive;
  final bool isMaintenance;
  final double basePrice;
  final double peakPrice;
  final double fixedSchedulePrice;
  final Map<String, double> hourlyPrices;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CourtModel({
    required this.id,
    required this.name,
    required this.code,
    required this.surfaceType,
    this.status = 'available',
    this.isActive = true,
    this.isMaintenance = false,
    this.basePrice = 0,
    this.peakPrice = 0,
    this.fixedSchedulePrice = 0,
    this.hourlyPrices = const <String, double>{},
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      surfaceType: json['surfaceType'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      isActive: json['isActive'] as bool? ?? true,
      isMaintenance: json['isMaintenance'] as bool? ?? false,
      basePrice: ModelJsonHelper.doubleFromJson(json['basePrice']),
      peakPrice: ModelJsonHelper.doubleFromJson(json['peakPrice']),
      fixedSchedulePrice: ModelJsonHelper.doubleFromJson(
        json['fixedSchedulePrice'],
      ),
      hourlyPrices: ModelJsonHelper.doubleMapFromJson(json['hourlyPrices']),
      imageUrl: ModelJsonHelper.nullableStringFromJson(json['imageUrl']),
      createdAt: ModelJsonHelper.dateTimeFromJson(json['createdAt']),
      updatedAt: ModelJsonHelper.dateTimeFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'surfaceType': surfaceType,
      'status': status,
      'isActive': isActive,
      'isMaintenance': isMaintenance,
      'basePrice': basePrice,
      'peakPrice': peakPrice,
      'fixedSchedulePrice': fixedSchedulePrice,
      'hourlyPrices': hourlyPrices,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CourtModel copyWith({
    String? id,
    String? name,
    String? code,
    String? surfaceType,
    String? status,
    bool? isActive,
    bool? isMaintenance,
    double? basePrice,
    double? peakPrice,
    double? fixedSchedulePrice,
    Map<String, double>? hourlyPrices,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourtModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      surfaceType: surfaceType ?? this.surfaceType,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      isMaintenance: isMaintenance ?? this.isMaintenance,
      basePrice: basePrice ?? this.basePrice,
      peakPrice: peakPrice ?? this.peakPrice,
      fixedSchedulePrice: fixedSchedulePrice ?? this.fixedSchedulePrice,
      hourlyPrices: hourlyPrices ?? this.hourlyPrices,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
