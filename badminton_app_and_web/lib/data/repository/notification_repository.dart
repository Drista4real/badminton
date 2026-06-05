import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<List<NotificationModel>> watchUserNotifications(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId.trim())
        .limit(500)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(_notificationFromSnapshot)
              .where((item) => !item.id.startsWith('fixed_booking_created_'))
              .toList();
          items.sort((left, right) {
            final leftDate = left.createdAt;
            final rightDate = right.createdAt;
            if (leftDate == null && rightDate == null) return 0;
            if (leftDate == null) return 1;
            if (rightDate == null) return -1;
            return rightDate.compareTo(leftDate);
          });
          return items;
        });
  }

  Future<void> markAsRead(String notificationId) {
    return _notifications.doc(notificationId.trim()).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notifications
        .where('userId', isEqualTo: userId.trim())
        .where('isRead', isEqualTo: false)
        .limit(500)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  NotificationModel _notificationFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = Map<String, dynamic>.from(snapshot.data());
    data['id'] ??= snapshot.id;
    return NotificationModel.fromJson(data);
  }
}
