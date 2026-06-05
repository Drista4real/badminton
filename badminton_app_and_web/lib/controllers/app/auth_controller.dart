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
  final registerPhoneController = TextEditingController();
  final registerPasswordController = TextEditingController();
  final registerConfirmPasswordController = TextEditingController();
  final forgotPasswordEmailController = TextEditingController();

  final isLoading = false.obs;
  final isEmailVerificationLoading = false.obs;
  final isAutoCheckingEmail = false.obs;
  final isPasswordResetLoading = false.obs;
  final isPasswordResetAutoChecking = false.obs;
  final isPasswordResetReadyToLogin = false.obs;
  final errorMessage = ''.obs;
  final verificationEmail = ''.obs;
  final passwordResetEmail = ''.obs;
  final resendSecondsLeft = 0.obs;
  final passwordResetResendSecondsLeft = 0.obs;

  Timer? _resendTimer;
  Timer? _passwordResetResendTimer;
  Timer? _passwordResetPollTimer;
  Timer? _verificationPollTimer;
  bool _isCheckingEmailVerification = false;

  bool get canResendEmail =>
      resendSecondsLeft.value == 0 && !isEmailVerificationLoading.value;

  bool get canResendPasswordReset =>
      passwordResetResendSecondsLeft.value == 0 &&
      !isPasswordResetLoading.value;

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
        await _tryEnsureUserDocument(user);
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
    final phoneNumber = registerPhoneController.text.trim();
    final password = registerPasswordController.text;
    final confirmPassword = registerConfirmPasswordController.text;

    if (fullName.isEmpty ||
        email.isEmpty ||
        phoneNumber.isEmpty ||
        password.isEmpty) {
      _showError(
        'Vui lòng nhập đầy đủ họ tên, email, số điện thoại và mật khẩu.',
      );
      return;
    }

    if (!GetUtils.isEmail(email)) {
      _showError('Email không hợp lệ.');
      return;
    }

    if (!_isValidPhoneNumber(phoneNumber)) {
      _showError('Số điện thoại không hợp lệ.');
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
        phoneNumber: phoneNumber,
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

      await _tryEnsureUserDocument(user);
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

  void openForgotPassword() {
    final email = loginEmailController.text.trim();
    forgotPasswordEmailController.text = email;
    passwordResetEmail.value = email;
    isPasswordResetReadyToLogin.value = false;
    errorMessage.value = '';
    Get.toNamed(AppRoutes.forgotPassword);
  }

  Future<void> requestPasswordReset() async {
    if (!canResendPasswordReset) return;

    final email = forgotPasswordEmailController.text.trim();
    if (email.isEmpty) {
      _showError('Vui lòng nhập email tài khoản.');
      return;
    }
    if (!GetUtils.isEmail(email)) {
      _showError('Email không hợp lệ.');
      return;
    }

    isPasswordResetLoading.value = true;
    errorMessage.value = '';
    try {
      await _authRepository.sendPasswordResetEmail(email: email);
      passwordResetEmail.value = email;
      isPasswordResetReadyToLogin.value = false;
      _startPasswordResetCooldown();
      startPasswordResetMonitor();
      Get.snackbar(
        'Đã gửi email đặt lại mật khẩu',
        'Vui lòng mở Gmail, bấm link đặt lại mật khẩu rồi quay lại app.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (error) {
      _showError(_firebaseMessage(error));
    } catch (_) {
      _showError('Không thể gửi email đặt lại mật khẩu. Vui lòng thử lại.');
    } finally {
      isPasswordResetLoading.value = false;
    }
  }

  void startPasswordResetMonitor() {
    isPasswordResetAutoChecking.value = true;
    _passwordResetPollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (isPasswordResetReadyToLogin.value) {
        _stopPasswordResetMonitor();
      }
    });
  }

  void stopPasswordResetMonitor() {
    _stopPasswordResetMonitor();
  }

  Future<void> backToLoginFromPasswordReset() async {
    _stopPasswordResetMonitor();
    Get.offAllNamed(AppRoutes.login);
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
    if (state == AppLifecycleState.resumed &&
        Get.currentRoute == AppRoutes.forgotPassword &&
        passwordResetEmail.value.isNotEmpty) {
      isPasswordResetReadyToLogin.value = true;
      _stopPasswordResetMonitor();
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

  void _startPasswordResetCooldown() {
    _passwordResetResendTimer?.cancel();
    passwordResetResendSecondsLeft.value = 60;
    _passwordResetResendTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (passwordResetResendSecondsLeft.value <= 0) {
        timer.cancel();
        _passwordResetResendTimer = null;
        return;
      }
      passwordResetResendSecondsLeft.value--;
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

  void _stopPasswordResetMonitor() {
    _passwordResetPollTimer?.cancel();
    _passwordResetPollTimer = null;
    isPasswordResetAutoChecking.value = false;
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
      case 'phone-already-in-use':
        return 'Số điện thoại này đã được sử dụng.';
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

  bool _isValidPhoneNumber(String phoneNumber) {
    final normalized = AuthRepository.normalizePhoneNumber(phoneNumber);
    return normalized.length == 10 && normalized.startsWith('0');
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
    _passwordResetResendTimer?.cancel();
    _stopVerificationPolling();
    _stopPasswordResetMonitor();
    loginEmailController.dispose();
    loginPasswordController.dispose();
    registerNameController.dispose();
    registerEmailController.dispose();
    registerPhoneController.dispose();
    registerPasswordController.dispose();
    registerConfirmPasswordController.dispose();
    forgotPasswordEmailController.dispose();
    super.onClose();
  }
}
