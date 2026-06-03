// ===============================
// FILE: lib/views/app/profile/change_password_screen.dart
// ===============================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../controllers/app/profile_controller.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final ProfileController _profileController;

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  // Password strength: 0 = empty, 1 = weak, 2 = medium, 3 = strong
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _profileController = Get.find<ProfileController>();
    _profileController.startPasswordChangeVerificationMonitor();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  void _checkPasswordStrength() {
    final password = _newPasswordController.text;
    if (password.isEmpty) {
      setState(() => _passwordStrength = 0);
      return;
    }
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      strength++;
    }
    if (RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#\$%^&*]').hasMatch(password)) {
      strength++;
    }
    setState(() => _passwordStrength = strength);
  }

  @override
  void dispose() {
    _profileController.stopPasswordChangeVerificationMonitor();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ),
        ),
        title: const Text(
          'Thay đổi mật khẩu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            _buildInfoBanner(),
            const SizedBox(height: 16),

            // Gmail verification
            _buildVerificationCard(),
            const SizedBox(height: 24),

            // Form
            _buildFormCard(),
            const SizedBox(height: 24),

            // Submit button
            _buildSubmitButton(),
            const SizedBox(height: 16),

            // Note
            _buildNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Trước khi đổi mật khẩu, bạn cần xác thực qua link gửi về Gmail. Link có hiệu lực 5 phút và chỉ được gửi lại sau 60 giây.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard() {
    return Obx(() {
      final isVerified = _profileController.isPasswordChangeVerified.value;
      final isLoading = _profileController.isPasswordVerificationLoading.value;
      final cooldown =
          _profileController.passwordVerificationCooldownSecondsLeft.value;
      final expiresIn =
          _profileController.passwordVerificationExpiresSecondsLeft.value;
      final hasActiveWindow = !isVerified && expiresIn > 0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isVerified ? Colors.green : AppColors.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified
                        ? Icons.verified_user_rounded
                        : Icons.mark_email_read_outlined,
                    color: isVerified ? Colors.green : AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? 'Gmail đã xác thực' : 'Xác thực Gmail',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified
                            ? 'Gmail đã được xác minh. Bạn có thể cập nhật mật khẩu.'
                            : 'Gửi link xác thực đến ${_profileController.passwordVerificationEmail}, mở link trong Gmail rồi quay lại app. Hệ thống sẽ tự kiểm tra.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasActiveWindow) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hiệu lực còn ${_profileController.passwordVerificationExpiryLabel}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isVerified) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _profileController.canSendPasswordVerification &&
                            !isLoading
                        ? _profileController.sendPasswordChangeVerification
                        : null,
                    icon: isLoading && cooldown == 0
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(
                      cooldown > 0
                          ? 'Gửi lại sau ${cooldown}s'
                          : hasActiveWindow
                          ? 'Gửi lại link'
                          : 'Gửi link xác thực',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildFormCard() {
    return Obx(() {
      final canEdit = _profileController.isPasswordChangeVerified.value;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current password
            _buildFieldLabel('Mật khẩu hiện tại'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _currentPasswordController,
              hint: '••••••••',
              showPassword: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              enabled: canEdit,
            ),
            const SizedBox(height: 20),

            // New password
            _buildFieldLabel('Mật khẩu mới'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _newPasswordController,
              hint: 'Nhập mật khẩu mới',
              showPassword: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              enabled: canEdit,
            ),

            // Password strength indicator
            if (_passwordStrength > 0) ...[
              const SizedBox(height: 10),
              _buildStrengthIndicator(),
            ],
            const SizedBox(height: 20),

            // Confirm password
            _buildFieldLabel('Xác nhận mật khẩu mới'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _confirmPasswordController,
              hint: 'Nhập lại mật khẩu mới',
              showPassword: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              enabled: canEdit,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: !showPassword,
        style: const TextStyle(fontSize: 14, color: AppColors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.grey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              showPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.grey,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthIndicator() {
    final labels = ['', 'Yếu', 'Trung bình', 'Mạnh'];
    final colors = [
      Colors.transparent,
      const Color(0xFFEF5350),
      const Color(0xFFFF9800),
      const Color(0xFF4CAF50),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < _passwordStrength
                      ? colors[_passwordStrength]
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Độ mạnh mật khẩu:',
              style: TextStyle(fontSize: 11, color: AppColors.grey),
            ),
            GestureDetector(
              onTap: () {},
              child: Text(
                labels[_passwordStrength],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors[_passwordStrength],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      final canSubmit =
          _profileController.isPasswordChangeVerified.value &&
          !_profileController.isChangingPassword.value;

      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: canSubmit ? _handleChangePassword : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: _profileController.isChangingPassword.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Cập nhật mật khẩu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    });
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF9A825), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Lưu ý: Sử dụng ít nhất 12 ký tự, kết hợp chữ hoa, thường, số và ký tự đặc biệt để được bảo mật tốt hơn.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF795548),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    final changed = await _profileController.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (!changed) return;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context);
    });
  }
}
