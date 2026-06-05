import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  Future<void>? _googleSignInInitialization;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isAuthenticated => _auth.currentUser != null;

  bool get currentUserRequiresEmailVerification {
    final user = _auth.currentUser;
    return user != null && requiresEmailVerification(user);
  }

  String? get currentUserId => _auth.currentUser?.uid;

  String? get currentDisplayName => _auth.currentUser?.displayName;

  String? get currentEmail => _auth.currentUser?.email;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    }

    await _initializeGoogleSignIn();

    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw FirebaseAuthException(
          code: 'google-sign-in-cancelled',
          message: 'Google sign-in was cancelled.',
        );
      }

      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: error.description ?? 'Google sign-in failed.',
      );
    }
  }

  Future<void> _initializeGoogleSignIn() {
    return _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
  }

  Future<UserCredential> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    try {
      await credential.user?.updateDisplayName(fullName.trim());

      final user = credential.user;
      if (user != null) {
        await _reservePhoneNumber(
          userId: user.uid,
          phoneNumber: normalizedPhoneNumber,
        );
        await ensureUserDocument(
          user,
          fullName: fullName,
          phoneNumber: normalizedPhoneNumber,
        );
      }

      await sendEmailVerification();
    } catch (_) {
      try {
        await credential.user?.delete();
      } catch (_) {
        // Best-effort rollback. Firebase may already have invalidated the session.
      }
      await _auth.signOut();
      rethrow;
    }

    return credential;
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user.',
      );
    }

    await user.sendEmailVerification();
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    if (user == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in email user.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> updateDisplayName(String fullName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user.',
      );
    }

    await user.updateDisplayName(fullName.trim());
  }

  Future<void> verifyBeforeUpdateEmail(String email) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user.',
      );
    }

    await user.verifyBeforeUpdateEmail(email.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user.',
      );
    }

    await user.updatePassword(newPassword);
  }

  Future<User?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    return _auth.currentUser;
  }

  Future<void> ensureUserDocument(
    User user, {
    String? fullName,
    String? phoneNumber,
  }) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    final now = FieldValue.serverTimestamp();
    final normalizedPhoneNumber = phoneNumber?.trim().isNotEmpty == true
        ? normalizePhoneNumber(phoneNumber!)
        : null;
    final authPhoneNumber = user.phoneNumber?.trim().isNotEmpty == true
        ? normalizePhoneNumber(user.phoneNumber!)
        : null;

    final existingAvatarUrl = snapshot.data()?['avatarUrl'] as String?;
    final data = <String, dynamic>{
      'id': user.uid,
      'email': user.email ?? '',
      'fullName': fullName?.trim().isNotEmpty == true
          ? fullName!.trim()
          : user.displayName ?? '',
      'emailVerified': user.emailVerified,
      'isActive': true,
      'updatedAt': now,
      if (!snapshot.exists) 'createdAt': now,
    };

    if (existingAvatarUrl?.trim().isNotEmpty != true &&
        user.photoURL?.trim().isNotEmpty == true) {
      data['avatarUrl'] = user.photoURL;
    }

    if (normalizedPhoneNumber != null) {
      data['phoneNumber'] = normalizedPhoneNumber;
    } else if (!snapshot.exists && authPhoneNumber != null) {
      data['phoneNumber'] = authPhoneNumber;
    }

    await ref.set(data, SetOptions(merge: true));
  }

  bool requiresEmailVerification(User user) {
    final email = user.email?.trim().toLowerCase();
    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );

    if (email == null || email.isEmpty || email.endsWith('.local')) {
      return false;
    }

    return hasPasswordProvider && !user.emailVerified;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await _initializeGoogleSignIn();
      await GoogleSignIn.instance.signOut();
    }
  }

  Future<void> _reservePhoneNumber({
    required String userId,
    required String phoneNumber,
  }) async {
    final phoneRef = _firestore.collection('phoneNumbers').doc(phoneNumber);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(phoneRef);
      final existingUserId = snapshot.data()?['userId'] as String?;
      if (snapshot.exists && existingUserId != userId) {
        throw FirebaseAuthException(
          code: 'phone-already-in-use',
          message: 'Phone number is already in use.',
        );
      }

      transaction.set(phoneRef, {
        'userId': userId,
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
