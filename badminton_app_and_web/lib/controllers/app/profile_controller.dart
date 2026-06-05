import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings_controller.dart';
import '../../data/models/user_model.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/user_repository.dart';
import '../../routes/app_routes.dart';

class ProfileController extends GetxController with WidgetsBindingObserver {
  ProfileController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository;

  static const courtAddress =
      '99 Man Thiện, Tăng Nhơn Phú, Hồ Chí Minh, Việt Nam';
  static const mapLocationLabel = 'Vị trí cơ sở cầu lông';
  static const _passwordVerificationCooldown = Duration(seconds: 60);
  static const _passwordVerificationLifetime = Duration(minutes: 5);
  static const _maxAvatarBytes = 260 * 1024;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final ImagePicker _imagePicker = ImagePicker();
  final AppSettingsController _settingsController =
      Get.find<AppSettingsController>();

  final profileNameController = TextEditingController();
  final profilePhoneController = TextEditingController();
  final profileEmailController = TextEditingController();

  final isLoading = true.obs;
  final isSavingProfile = false.obs;
  final isChangingPassword = false.obs;
  final isUpdatingAvatar = false.obs;
  final isPasswordVerificationLoading = false.obs;
  final isPasswordChangeVerified = false.obs;
  final isDarkMode = false.obs;
  final selectedLanguageCode = 'vi'.obs;
  final passwordVerificationCooldownSecondsLeft = 0.obs;
  final passwordVerificationExpiresSecondsLeft = 0.obs;
  final user = Rxn<UserModel>();

  StreamSubscription<UserModel?>? _userSubscription;
  Timer? _passwordVerificationCooldownTimer;
  Timer? _passwordVerificationExpiryTimer;
  Timer? _passwordVerificationPollTimer;
  DateTime? _passwordVerificationExpiresAt;
  bool _isCheckingPasswordVerification = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _syncSettingsPreference();
    _watchUserProfile();
  }

  String get fullName {
    final profileName = user.value?.fullName.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;

    final displayName = _authRepository.currentDisplayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = emailAddress;
    return email.isEmpty ? 'Người dùng' : email.split('@').first;
  }

  String get emailAddress {
    final profileEmail = user.value?.email.trim();
    if (profileEmail != null && profileEmail.isNotEmpty) return profileEmail;
    return _authRepository.currentEmail?.trim() ?? '';
  }

  String get phoneNumber {
    final phone = user.value?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return _authRepository.currentUser?.phoneNumber?.trim().isNotEmpty == true
        ? _authRepository.currentUser!.phoneNumber!.trim()
        : 'Chưa cập nhật';
  }

  String? get avatarUrl {
    final profileAvatar = user.value?.avatarUrl?.trim();
    if (profileAvatar != null && profileAvatar.isNotEmpty) {
      return profileAvatar;
    }
    final firebaseAvatar = _authRepository.currentUser?.photoURL?.trim();
    return firebaseAvatar?.isNotEmpty == true ? firebaseAvatar : null;
  }

  bool get canSendPasswordVerification =>
      !isPasswordChangeVerified.value &&
      passwordVerificationCooldownSecondsLeft.value == 0 &&
      !isPasswordVerificationLoading.value;

  bool get hasActivePasswordVerificationWindow =>
      _passwordVerificationExpiresAt != null &&
      DateTime.now().isBefore(_passwordVerificationExpiresAt!);

  String get passwordVerificationEmail {
    final authEmail = _authRepository.currentEmail?.trim();
    if (authEmail != null && authEmail.isNotEmpty) return authEmail;
    return emailAddress;
  }

  String get passwordVerificationExpiryLabel {
    final seconds = passwordVerificationExpiresSecondsLeft.value;
    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        Get.currentRoute == AppRoutes.changePassword) {
      startPasswordChangeVerificationMonitor();
    }
  }

  void syncProfileForm() {
    profileNameController.text = fullName;
    profilePhoneController.text = phoneNumber == 'Chưa cập nhật'
        ? ''
        : phoneNumber;
    profileEmailController.text = emailAddress;
  }

  Future<void> toggleDarkMode(bool value) async {
    await _settingsController.setDarkMode(value);
    isDarkMode.value = _settingsController.isDarkMode.value;
  }

  Future<void> changeLanguage(String languageCode) async {
    await _settingsController.setLanguage(languageCode);
    selectedLanguageCode.value = _settingsController.locale.value.languageCode;
  }

  Future<void> toggleLanguage(bool useEnglish) {
    return changeLanguage(useEnglish ? 'en' : 'vi');
  }

  Future<bool> saveProfileChanges(String currentPassword) async {
    if (isSavingProfile.value) return false;

    final userId = _authRepository.currentUserId;
    final fullName = profileNameController.text.trim();
    final phoneNumber = profilePhoneController.text.trim();
    final email = profileEmailController.text.trim();

    if (userId == null || userId.isEmpty) {
      _showError('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      return false;
    }
    if (fullName.isEmpty) {
      _showError('Vui lòng nhập họ và tên.');
      return false;
    }
    if (!GetUtils.isEmail(email)) {
      _showError('Email không hợp lệ.');
      return false;
    }
    if (phoneNumber.isNotEmpty && !_isValidPhoneNumber(phoneNumber)) {
      _showError('Số điện thoại không hợp lệ.');
      return false;
    }
    if (currentPassword.isEmpty) {
      _showError('Vui lòng nhập mật khẩu hiện tại để xác thực.');
      return false;
    }

    isSavingProfile.value = true;
    try {
      await _authRepository.reauthenticateWithPassword(currentPassword);
      await _authRepository.updateDisplayName(fullName);

      final currentEmail = _authRepository.currentEmail?.trim();
      final isEmailChanged =
          currentEmail != null &&
          currentEmail.isNotEmpty &&
          email.toLowerCase() != currentEmail.toLowerCase();
      if (isEmailChanged) {
        await _authRepository.verifyBeforeUpdateEmail(email);
      }

      final profileUpdates = {
        'fullName': fullName,
        'email': email,
        if (isEmailChanged) 'emailVerified': false,
      };
      if (phoneNumber.isEmpty) {
        await _userRepository.updateUserProfile(userId, profileUpdates);
      } else {
        final previousPhoneNumber = user.value?.phoneNumber;
        await _userRepository.updateUserProfileWithUniquePhone(
          userId,
          profileUpdates,
          phoneNumber: phoneNumber,
          previousPhoneNumber: previousPhoneNumber,
        );
      }
      await _authRepository.reloadCurrentUser();

      Get.snackbar(
        'Đã cập nhật',
        isEmailChanged
            ? 'Thông tin đã lưu. Vui lòng mở link xác minh trong Gmail để hoàn tất đổi email.'
            : 'Thông tin cá nhân đã được cập nhật.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } on FirebaseAuthException catch (error) {
      _showError(_firebaseMessage(error));
      return false;
    } on FirebaseException catch (error) {
      if (error.code == 'phone-already-in-use') {
        _showError('Số điện thoại này đã được sử dụng cho tài khoản khác.');
      } else {
        _showError('Không thể cập nhật thông tin. Vui lòng thử lại.');
      }
      return false;
    } catch (_) {
      _showError('Không thể cập nhật thông tin. Vui lòng thử lại.');
      return false;
    } finally {
      isSavingProfile.value = false;
    }
  }

  Future<void> updateAvatarFromGallery() async {
    if (isUpdatingAvatar.value) return;

    final userId = _authRepository.currentUserId;
    if (userId == null || userId.isEmpty) {
      _showError('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      return;
    }

    isUpdatingAvatar.value = true;
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 58,
      );
      if (pickedImage == null) {
        return;
      }

      final bytes = await pickedImage.readAsBytes();
      if (bytes.length > _maxAvatarBytes) {
        _showError('Ảnh đại diện quá lớn. Vui lòng chọn ảnh nhỏ hơn.');
        return;
      }

      final mimeType = pickedImage.mimeType?.trim().isNotEmpty == true
          ? pickedImage.mimeType!.trim()
          : 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      final currentUser = _authRepository.currentUser;
      if (currentUser != null) {
        await _authRepository.ensureUserDocument(currentUser);
      }
      await _userRepository.updateUserProfile(userId, {'avatarUrl': dataUrl});
      user.value = user.value?.copyWith(avatarUrl: dataUrl);

      Get.snackbar(
        'Đã cập nhật',
        'Ảnh đại diện đã được thay đổi.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseException catch (error) {
      _showError(_avatarUpdateMessage(error));
    } catch (_) {
      _showError('Không thể cập nhật ảnh đại diện. Vui lòng thử lại.');
    } finally {
      isUpdatingAvatar.value = false;
    }
  }

  Future<void> sendPasswordChangeVerification() async {
    if (!canSendPasswordVerification) return;

    if (_authRepository.currentUser?.emailVerified == true) {
      _markPasswordChangeVerified();
      return;
    }

    final email = passwordVerificationEmail;
    if (email.isEmpty) {
      _showError('Tài khoản chưa có email để gửi link xác thực.');
      return;
    }

    isPasswordVerificationLoading.value = true;
    try {
      await _authRepository.sendEmailVerification();
      isPasswordChangeVerified.value = false;
      _startPasswordVerificationWindow();
      _startPasswordVerificationCooldown();
      _startPasswordVerificationPolling();

      Get.snackbar(
        'Đã gửi link xác thực',
        'Vui lòng kiểm tra Gmail $email. Link có hiệu lực trong 5 phút.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (error) {
      _showError(_firebaseMessage(error));
    } catch (_) {
      _showError('Không thể gửi link xác thực. Vui lòng thử lại.');
    } finally {
      isPasswordVerificationLoading.value = false;
    }
  }

  Future<void> confirmPasswordChangeVerification() async {
    if (!hasActivePasswordVerificationWindow &&
        !isPasswordChangeVerified.value) {
      isPasswordChangeVerified.value = false;
      _showError('Link xác thực đã hết hạn. Vui lòng gửi lại link mới.');
      return;
    }

    await checkPasswordChangeVerification(silent: false);
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (isChangingPassword.value) return false;
    if (!isPasswordChangeVerified.value) {
      _showError('Vui lòng xác thực Gmail trước khi đổi mật khẩu.');
      return false;
    }
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('Vui lòng điền đầy đủ thông tin.');
      return false;
    }
    if (newPassword != confirmPassword) {
      _showError('Mật khẩu xác nhận không khớp.');
      return false;
    }
    if (newPassword.length < 8) {
      _showError('Mật khẩu phải có ít nhất 8 ký tự.');
      return false;
    }

    isChangingPassword.value = true;
    try {
      await _authRepository.reauthenticateWithPassword(currentPassword);
      await _authRepository.updatePassword(newPassword);
      _clearPasswordVerification();

      Get.snackbar(
        'Thành công',
        'Mật khẩu đã được cập nhật.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } on FirebaseAuthException catch (error) {
      _showError(_firebaseMessage(error));
      return false;
    } catch (_) {
      _showError('Không thể đổi mật khẩu. Vui lòng thử lại.');
      return false;
    } finally {
      isChangingPassword.value = false;
    }
  }

  void startPasswordChangeVerificationMonitor() {
    if (_authRepository.currentUser?.emailVerified == true) {
      _markPasswordChangeVerified();
      return;
    }

    checkPasswordChangeVerification(silent: true);
    if (hasActivePasswordVerificationWindow) {
      _startPasswordVerificationPolling();
    }
  }

  void stopPasswordChangeVerificationMonitor() {
    _stopPasswordVerificationPolling();
  }

  Future<void> checkPasswordChangeVerification({bool silent = false}) async {
    if (_isCheckingPasswordVerification) return;

    _isCheckingPasswordVerification = true;
    if (!silent) {
      isPasswordVerificationLoading.value = true;
    }

    try {
      final currentUser = await _authRepository.reloadCurrentUser();
      if (currentUser == null) {
        _clearPasswordVerification();
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      if (currentUser.emailVerified) {
        final wasVerified = isPasswordChangeVerified.value;
        _markPasswordChangeVerified();
        if (!silent && !wasVerified) {
          Get.snackbar(
            'Đã xác thực',
            'Bạn có thể cập nhật mật khẩu.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }

      if (!silent) {
        _showError(
          'Email chưa được xác minh. Hãy mở link trong Gmail rồi thử lại.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!silent) {
        _showError(_firebaseMessage(error));
      }
    } catch (_) {
      if (!silent) {
        _showError('Không thể kiểm tra trạng thái xác thực.');
      }
    } finally {
      _isCheckingPasswordVerification = false;
      if (!silent) {
        isPasswordVerificationLoading.value = false;
      }
    }
  }

  Future<void> openCourtLocation() async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': courtAddress,
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      Get.snackbar(
        'Không thể mở bản đồ',
        'Vui lòng kiểm tra ứng dụng Google Maps hoặc trình duyệt.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    Get.offAllNamed(AppRoutes.login);
  }

  void _syncSettingsPreference() {
    isDarkMode.value = _settingsController.isDarkMode.value;
    selectedLanguageCode.value = _settingsController.locale.value.languageCode;
  }

  void _watchUserProfile() {
    final userId = _authRepository.currentUserId;
    if (userId == null || userId.isEmpty) {
      isLoading.value = false;
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    _userSubscription = _userRepository
        .watchUserProfile(userId)
        .listen(
          (profile) {
            user.value = profile;
            isLoading.value = false;
          },
          onError: (_) {
            isLoading.value = false;
          },
        );
  }

  void _startPasswordVerificationCooldown() {
    _passwordVerificationCooldownTimer?.cancel();
    passwordVerificationCooldownSecondsLeft.value =
        _passwordVerificationCooldown.inSeconds;
    _passwordVerificationCooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        final nextValue = passwordVerificationCooldownSecondsLeft.value - 1;
        if (nextValue <= 0) {
          passwordVerificationCooldownSecondsLeft.value = 0;
          timer.cancel();
          return;
        }

        passwordVerificationCooldownSecondsLeft.value = nextValue;
      },
    );
  }

  void _startPasswordVerificationWindow() {
    _passwordVerificationExpiryTimer?.cancel();
    _passwordVerificationExpiresAt = DateTime.now().add(
      _passwordVerificationLifetime,
    );
    passwordVerificationExpiresSecondsLeft.value =
        _passwordVerificationLifetime.inSeconds;

    _passwordVerificationExpiryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        final expiresAt = _passwordVerificationExpiresAt;
        if (expiresAt == null) {
          passwordVerificationExpiresSecondsLeft.value = 0;
          timer.cancel();
          return;
        }

        final secondsLeft = expiresAt.difference(DateTime.now()).inSeconds;
        if (secondsLeft <= 0) {
          passwordVerificationExpiresSecondsLeft.value = 0;
          _passwordVerificationExpiresAt = null;
          timer.cancel();
          _stopPasswordVerificationPolling();
          return;
        }

        passwordVerificationExpiresSecondsLeft.value = secondsLeft;
      },
    );
  }

  void _startPasswordVerificationPolling() {
    _passwordVerificationPollTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => checkPasswordChangeVerification(silent: true),
    );
  }

  void _stopPasswordVerificationPolling() {
    _passwordVerificationPollTimer?.cancel();
    _passwordVerificationPollTimer = null;
  }

  void _markPasswordChangeVerified() {
    isPasswordChangeVerified.value = true;
    passwordVerificationCooldownSecondsLeft.value = 0;
    passwordVerificationExpiresSecondsLeft.value = 0;
    _passwordVerificationExpiresAt = null;
    _passwordVerificationCooldownTimer?.cancel();
    _passwordVerificationCooldownTimer = null;
    _passwordVerificationExpiryTimer?.cancel();
    _passwordVerificationExpiryTimer = null;
    _stopPasswordVerificationPolling();
  }

  void _clearPasswordVerification() {
    isPasswordChangeVerified.value = false;
    passwordVerificationExpiresSecondsLeft.value = 0;
    _passwordVerificationExpiresAt = null;
    _passwordVerificationCooldownTimer?.cancel();
    _passwordVerificationCooldownTimer = null;
    passwordVerificationCooldownSecondsLeft.value = 0;
    _passwordVerificationExpiryTimer?.cancel();
    _passwordVerificationExpiryTimer = null;
    _stopPasswordVerificationPolling();
  }

  String _firebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hiện tại không đúng.';
      case 'requires-recent-login':
        return 'Vui lòng xác thực lại trước khi thực hiện thao tác này.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu mới quá yếu.';
      case 'too-many-requests':
        return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản. Vui lòng đăng nhập lại.';
      default:
        return error.message ?? 'Có lỗi xác thực. Vui lòng thử lại.';
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Không thể thực hiện',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    final normalized = UserRepository.normalizePhoneNumber(phoneNumber);
    return normalized.length == 10 && normalized.startsWith('0');
  }

  String _avatarUpdateMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Không có quyền cập nhật ảnh. Vui lòng đăng nhập lại hoặc kiểm tra Firestore rules.';
      case 'not-found':
        return 'Chưa có hồ sơ người dùng để cập nhật ảnh. Vui lòng đăng nhập lại.';
      case 'resource-exhausted':
      case 'invalid-argument':
        return 'Ảnh quá lớn để lưu. Vui lòng chọn ảnh nhỏ hơn.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Không thể cập nhật ảnh đại diện. Vui lòng thử lại.';
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _userSubscription?.cancel();
    _passwordVerificationCooldownTimer?.cancel();
    _passwordVerificationExpiryTimer?.cancel();
    _passwordVerificationPollTimer?.cancel();
    profileNameController.dispose();
    profilePhoneController.dispose();
    profileEmailController.dispose();
    super.onClose();
  }
}
