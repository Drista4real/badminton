import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repository/auth_repository.dart';
import '../../routes/app_routes.dart';

class AuthController extends GetxController with WidgetsBindingObserver {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  static const pendingEmailVerificationUserKey =
      'pending_email_verification_user_id';

  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();
  final registerNameController = TextEditingController();
  final registerEmailController = TextEditingController();
  final registerPasswordController = TextEditingController();
  final registerConfirmPasswordController = TextEditingController();

  final isLoading = false.obs;
  final isEmailVerificationLoading = false.obs;
  final isAutoCheckingEmail = false.obs;
  final errorMessage = ''.obs;
  final verificationEmail = ''.obs;
  final resendSecondsLeft = 0.obs;

  Timer? _resendTimer;
  Timer? _verificationPollTimer;
  bool _isCheckingEmailVerification = false;

  bool get canResendEmail =>
      resendSecondsLeft.value == 0 && !isEmailVerificationLoading.value;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> signInWithEmailAndPassword() async {
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Vui lòng nhập email và mật khẩu.');
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final credential = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null && _needsEmailVerification(user)) {
        verificationEmail.value = user.email ?? email;
        await _markPendingEmailVerification(user.uid);
        await _sendVerificationEmailSilently();
        Get.offAllNamed(AppRoutes.otp);
        return;
      }

      if (user != null) {
        await _authRepository.ensureUserDocument(user);
      }
      Get.offAllNamed(AppRoutes.home);
    } on FirebaseAuthException catch (error) {
      _showError(_firebaseMessage(error));
    } catch (_) {
      _showError('Không thể đăng nhập. Vui lòng thử lại.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register() async {
    final fullName = registerNameController.text.trim();
    final email = registerEmailController.text.trim();
    final password = registerPasswordController.text;
    final confirmPassword = registerConfirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Vui lòng nhập đầy đủ họ tên, email và mật khẩu.');
      return;
    }

    if (password != confirmPassword) {
      _showError('Mật khẩu nhập lại không khớp.');
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final credential = await _authRepository.register(
        fullName: fullName,
        email: email,
        password: password,
      );
      verificationEmail.value = credential.user?.email ?? email;
      if (credential.user != null) {
        await _markPendingEmailVerification(credential.user!.uid);
      }
      _startResendCooldown();
      Get.snackbar(
        'Đã gửi email xác minh',
        'Vui lòng mở Gmail, bấm link xác minh rồi quay lại app.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.offAllNamed(AppRoutes.otp);
    } on FirebaseAuthException catch (error) {
      _showError(_firebaseMessage(error));
    } catch (_) {
      _showError('Không thể tạo tài khoản. Vui lòng thử lại.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    if (isLoading.value) return;

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final credential = await _authRepository.signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        _showError('Không lấy được thông tin tài khoản Google.');
        return;
      }

      await _authRepository.ensureUserDocument(user);
      Get.offAllNamed(AppRoutes.home);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'web-context-canceled' ||
          error.code == 'google-sign-in-cancelled') {
        return;
      }
      _showError(_firebaseMessage(error));
    } catch (_) {
      _showError('Không thể đăng nhập bằng Google. Vui lòng thử lại.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendEmailVerification() async {
    if (!canResendEmail) return;

    isEmailVerificationLoading.value = true;
    errorMessage.value = '';
    try {
      await _authRepository.sendEmailVerification();
      _startResendCooldown();
      startEmailVerificationPolling();
      Get.snackbar(
        'Đã gửi email',
        'Vui lòng kiểm tra hộp thư đến hoặc thư rác.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (error) {
      _showError(_firebaseMessage(error));
    } catch (_) {
      _showError('Không thể gửi email xác minh. Vui lòng thử lại.');
    } finally {
      isEmailVerificationLoading.value = false;
    }
  }

  void ensureResendCooldownStarted() {
    if (resendSecondsLeft.value > 0) return;

    _startResendCooldown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        Get.currentRoute == AppRoutes.otp) {
      startEmailVerificationPolling();
      checkEmailVerification(silent: true);
    }
  }

  Future<void> checkEmailVerification({bool silent = false}) async {
    if (_isCheckingEmailVerification) return;

    _isCheckingEmailVerification = true;
    if (silent) {
      isAutoCheckingEmail.value = true;
    } else {
      isEmailVerificationLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final user = await _authRepository.reloadCurrentUser();
      if (user == null) {
        _stopVerificationPolling();
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      verificationEmail.value = user.email ?? verificationEmail.value;
      if (!user.emailVerified) {
        if (!silent) {
          _showError(
            'Email chưa được xác minh. Hãy mở link trong Gmail rồi quay lại app.',
          );
        }
        return;
      }

      _stopVerificationPolling();
      await _tryEnsureUserDocument(user);
      await _clearPendingEmailVerification();
      await _authRepository.signOut();
      Get.offAllNamed(AppRoutes.login);
      Get.snackbar(
        'Email đã được xác minh',
        'Vui lòng đăng nhập để vào hệ thống.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (error) {
      if (!silent) {
        _showError(_firebaseMessage(error));
      }
    } catch (_) {
      if (!silent) {
        _showError('Không thể kiểm tra trạng thái xác minh.');
      }
    } finally {
      _isCheckingEmailVerification = false;
      if (silent) {
        isAutoCheckingEmail.value = false;
      } else {
        isEmailVerificationLoading.value = false;
      }
    }
  }

  Future<void> backToLogin() async {
    _stopVerificationPolling();
    await _authRepository.signOut();
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> _tryEnsureUserDocument(User user) async {
    try {
      await _authRepository.ensureUserDocument(user);
    } catch (_) {
      // Profile creation must not keep verified users stuck on this screen.
      // The next successful login can sync the profile again.
    }
  }

  bool _needsEmailVerification(User user) {
    return _authRepository.requiresEmailVerification(user);
  }

  Future<void> _sendVerificationEmailSilently() async {
    try {
      await _authRepository.sendEmailVerification();
      _startResendCooldown();
    } catch (_) {
      // If Firebase rate-limits email sending, still keep user on verification screen.
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    resendSecondsLeft.value = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSecondsLeft.value <= 0) {
        timer.cancel();
        _resendTimer = null;
        return;
      }
      resendSecondsLeft.value--;
    });
  }

  void startEmailVerificationPolling() {
    final user = _authRepository.currentUser;
    if (user != null) {
      verificationEmail.value = user.email ?? verificationEmail.value;
    }

    Future.microtask(() => checkEmailVerification(silent: true));

    _verificationPollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      checkEmailVerification(silent: true);
    });
  }

  void stopEmailVerificationPolling() {
    _stopVerificationPolling();
  }

  void _stopVerificationPolling() {
    _verificationPollTimer?.cancel();
    _verificationPollTimer = null;
    isAutoCheckingEmail.value = false;
  }

  Future<void> _markPendingEmailVerification(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingEmailVerificationUserKey, userId);
  }

  Future<void> _clearPendingEmailVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingEmailVerificationUserKey);
  }

  String _firebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu.';
      case 'too-many-requests':
        return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';
      case 'invalid-cert-hash':
        return 'Cấu hình đăng nhập Google chưa đúng. Vui lòng thêm SHA-1/SHA-256 của app vào Firebase.';
      default:
        if ((error.message ?? '').contains('INVALID_CERT_HASH')) {
          return 'Cấu hình đăng nhập Google chưa đúng. Vui lòng thêm SHA-1/SHA-256 của app vào Firebase.';
        }
        return error.message ?? 'Có lỗi xác thực. Vui lòng thử lại.';
    }
  }

  void _showError(String message) {
    errorMessage.value = message;
    Get.snackbar(
      'Không thể xác thực',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _resendTimer?.cancel();
    _stopVerificationPolling();
    loginEmailController.dispose();
    loginPasswordController.dispose();
    registerNameController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    registerConfirmPasswordController.dispose();
    super.onClose();
  }
}
