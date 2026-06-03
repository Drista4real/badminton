import 'package:cloud_firestore/cloud_firestore.dart';

class ModelJsonHelper {
  ModelJsonHelper._();

  static DateTime? dateTimeFromJson(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double doubleFromJson(Object? value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int intFromJson(Object? value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static List<String> stringListFromJson(Object? value) {
    if (value is Iterable) {
      return value.map((item) => item.toString()).toList();
    }
    return <String>[];
  }

  static String? nullableStringFromJson(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, double> doubleMapFromJson(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), doubleFromJson(item)),
      );
    }
    return <String, double>{};
  }
}
