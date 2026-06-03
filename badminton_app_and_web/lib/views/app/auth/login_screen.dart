import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../commons/widgets/custom_button.dart';
import '../../../commons/widgets/custom_textfield.dart';
import '../../../controllers/app/auth_controller.dart';
import '../../../routes/app_routes.dart';

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

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
                  'assets/images/onboarding3.jpg',
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
                  const _AuthLogo(),
                  const SizedBox(height: 32),
                  const Text(
                    'Chào mừng trở lại',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Đăng nhập bằng email đã xác minh hoặc Google',
                    style: TextStyle(fontSize: 14, color: AppColors.grey),
                  ),
                  const SizedBox(height: 28),
                  CustomTextField(
                    controller: controller.loginEmailController,
                    hint: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),
                  CustomTextField(
                    controller: controller.loginPasswordController,
                    hint: 'Mật khẩu',
                    icon: Icons.lock_outline,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => controller.signInWithEmailAndPassword(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Obx(
                    () => CustomButton(
                      text: 'Đăng nhập',
                      isLoading: controller.isLoading.value,
                      onTap: controller.signInWithEmailAndPassword,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: controller.isLoading.value
                            ? null
                            : controller.signInWithGoogle,
                        icon: const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        label: const Text(
                          'Đăng nhập với Google',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tài khoản email cần bấm link xác minh trong Gmail trước khi vào hệ thống.',
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
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Bạn chưa có tài khoản? ',
                        style: TextStyle(color: AppColors.grey),
                      ),
                      GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.register),
                        child: const Text(
                          'Đăng ký',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.sports_tennis_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ShuttleGo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            Text(
              'badminton',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
