import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../commons/widgets/custom_button.dart';
import '../../../commons/widgets/custom_textfield.dart';
import '../../../controllers/app/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  AuthController get controller => Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    if (controller.passwordResetEmail.value.isNotEmpty) {
      controller.startPasswordResetMonitor();
    }
  }

  @override
  void dispose() {
    controller.stopPasswordResetMonitor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.24,
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/onboarding1.jpg',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.transparent],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.black,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quên mật khẩu',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhập Gmail đã xác minh của tài khoản. Hệ thống sẽ gửi link đặt lại mật khẩu vào Gmail của bạn.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.grey,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    controller: controller.forgotPasswordEmailController,
                    hint: 'Email / Gmail',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => controller.requestPasswordReset(),
                  ),
                  _StatusPanel(controller: controller),
                  const SizedBox(height: 18),
                  Obx(
                    () => CustomButton(
                      text: controller.passwordResetResendSecondsLeft.value > 0
                          ? 'Gửi lại sau ${controller.passwordResetResendSecondsLeft.value}s'
                          : controller.passwordResetEmail.value.isEmpty
                          ? 'Gửi link đặt lại mật khẩu'
                          : 'Gửi lại link đặt lại mật khẩu',
                      isLoading: controller.isPasswordResetLoading.value,
                      onTap: controller.requestPasswordReset,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: controller.backToLoginFromPasswordReset,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Quay về đăng nhập'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.black,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final email = controller.passwordResetEmail.value;
      if (email.isEmpty) {
        return const SizedBox.shrink();
      }

      final readyToLogin = controller.isPasswordResetReadyToLogin.value;
      final isChecking = controller.isPasswordResetAutoChecking.value;

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (readyToLogin ? Colors.green : AppColors.primary).withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (readyToLogin ? Colors.green : AppColors.primary).withValues(
              alpha: 0.18,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isChecking)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              Icon(
                readyToLogin
                    ? Icons.check_circle_outline_rounded
                    : Icons.mark_email_read_outlined,
                color: readyToLogin ? Colors.green : AppColors.primary,
                size: 20,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                readyToLogin
                    ? 'Nếu bạn đã đặt lại mật khẩu trong Gmail, hãy đăng nhập lại bằng mật khẩu mới.'
                    : 'Đã gửi link đến $email. Hãy mở Gmail, đặt lại mật khẩu rồi quay lại app; màn hình sẽ tự cập nhật khi bạn quay lại.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
