import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../commons/widgets/custom_button.dart';
import '../../../controllers/app/auth_controller.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  AuthController get controller => Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    controller.ensureResendCooldownStarted();
    controller.startEmailVerificationPolling();
  }

  @override
  void dispose() {
    controller.stopEmailVerificationPolling();
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
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Kiểm tra Gmail',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Text(
                      controller.verificationEmail.value.isEmpty
                          ? 'Chúng tôi đã gửi link xác minh đến email của bạn.'
                          : 'Chúng tôi đã gửi link xác minh đến ${controller.verificationEmail.value}.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grey,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Obx(
                    () => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (controller.isAutoCheckingEmail.value)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            const Icon(
                              Icons.sync_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'App đang tự kiểm tra trạng thái xác minh. Sau khi bạn bấm link trong Gmail và quay lại app, hệ thống sẽ tự chuyển về màn đăng nhập.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.grey,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepRow(
                          index: '1',
                          text: 'Mở Gmail hoặc hộp thư email của bạn.',
                        ),
                        SizedBox(height: 10),
                        _StepRow(
                          index: '2',
                          text: 'Bấm vào link xác minh tài khoản từ Firebase.',
                        ),
                        SizedBox(height: 10),
                        _StepRow(
                          index: '3',
                          text:
                              'Quay lại app và chờ vài giây. Sau khi xác minh xong, hãy đăng nhập lại để vào hệ thống.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Obx(
                    () => CustomButton(
                      text: controller.resendSecondsLeft.value > 0
                          ? 'Gửi lại sau ${controller.resendSecondsLeft.value}s'
                          : 'Gửi lại email xác minh',
                      isLoading: controller.isEmailVerificationLoading.value,
                      onTap: controller.resendEmailVerification,
                    ),
                  ),
                  SizedBox(height: size.height * 0.18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
