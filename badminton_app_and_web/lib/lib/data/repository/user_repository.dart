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
}
