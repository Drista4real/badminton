import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<UserModel?> watchUserProfile(String userId) {
    return _users.doc(userId.trim()).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return _userFromSnapshot(snapshot);
    });
  }

  Future<UserModel?> getUserProfile(String userId) async {
    final snapshot = await _users.doc(userId.trim()).get();
    if (!snapshot.exists) {
      return null;
    }

    return _userFromSnapshot(snapshot);
  }

  Future<void> createUserProfile(UserModel user) {
    final data = _normalizeForWrite(user.toJson());
    data['id'] = user.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    return _users.doc(user.id.trim()).set(data);
  }

  Future<void> upsertUserProfile(UserModel user) {
    final data = _normalizeForWrite(user.toJson());
    data['id'] = user.id;
    data['updatedAt'] = FieldValue.serverTimestamp();

    return _users.doc(user.id.trim()).set(data, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) {
    final data = Map<String, dynamic>.from(updates)
      ..removeWhere((_, value) => value == null);
    data['updatedAt'] = FieldValue.serverTimestamp();

    return _users.doc(userId.trim()).update(data);
  }

  Future<void> updateUserProfileWithUniquePhone(
    String userId,
    Map<String, dynamic> updates, {
    required String phoneNumber,
    String? previousPhoneNumber,
  }) async {
    final trimmedUserId = userId.trim();
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    final normalizedPreviousPhoneNumber =
        previousPhoneNumber?.trim().isNotEmpty == true
        ? normalizePhoneNumber(previousPhoneNumber!)
        : null;

    final userRef = _users.doc(trimmedUserId);
    final phoneRef = _firestore
        .collection('phoneNumbers')
        .doc(normalizedPhoneNumber);
    final previousPhoneRef =
        normalizedPreviousPhoneNumber != null &&
            normalizedPreviousPhoneNumber != normalizedPhoneNumber
        ? _firestore
              .collection('phoneNumbers')
              .doc(normalizedPreviousPhoneNumber)
        : null;
    final data = Map<String, dynamic>.from(updates)
      ..removeWhere((_, value) => value == null);
    data['phoneNumber'] = normalizedPhoneNumber;
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final phoneSnapshot = await transaction.get(phoneRef);
      final existingUserId = phoneSnapshot.data()?['userId'] as String?;
      if (phoneSnapshot.exists && existingUserId != trimmedUserId) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'phone-already-in-use',
          message: 'Phone number is already in use.',
        );
      }

      transaction.update(userRef, data);
      transaction.set(phoneRef, {
        'userId': trimmedUserId,
        'phoneNumber': normalizedPhoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!phoneSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (previousPhoneRef != null) {
        transaction.delete(previousPhoneRef);
      }
    });
  }

  Future<void> deleteUserProfile(String userId) {
    return _users.doc(userId.trim()).delete();
  }

  UserModel _userFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = Map<String, dynamic>.from(snapshot.data() ?? {});
    data['id'] ??= snapshot.id;
    data['loyaltyPoints'] ??= data['points'] ?? data['rewardPoints'] ?? 0;
    return UserModel.fromJson(data);
  }

  Map<String, dynamic> _normalizeForWrite(Map<String, dynamic> data) {
    return Map<String, dynamic>.from(data)
      ..removeWhere((_, value) => value == null);
  }

  static String normalizePhoneNumber(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0084')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('84') && digits.length == 11) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }
}
