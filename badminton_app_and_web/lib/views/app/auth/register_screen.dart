import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../commons/widgets/custom_button.dart';
import '../../../commons/widgets/custom_textfield.dart';
import '../../../controllers/app/auth_controller.dart';

class RegisterScreen extends GetView<AuthController> {
  const RegisterScreen({super.key});

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
            height: size.height * 0.22,
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/onboarding2.jpg',
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
                  const SizedBox(height: 24),
                  const Text(
                    'Tạo tài khoản',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sau khi đăng ký, hệ thống sẽ gửi link xác minh vào Gmail của bạn.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    controller: controller.registerNameController,
                    hint: 'Họ và tên',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                  ),
                  CustomTextField(
                    controller: controller.registerEmailController,
                    hint: 'Email / Gmail',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),
                  CustomTextField(
                    controller: controller.registerPhoneController,
                    hint: 'Số điện thoại',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  CustomPasswordTextField(
                    controller: controller.registerPasswordController,
                    hint: 'Mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  CustomPasswordTextField(
                    controller: controller.registerConfirmPasswordController,
                    hint: 'Nhập lại mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => controller.register(),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => CustomButton(
                      text: 'Đăng ký và gửi email xác minh',
                      isLoading: controller.isLoading.value,
                      onTap: controller.register,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(color: AppColors.grey),
                      ),
                      GestureDetector(
                        onTap: Get.back,
                        child: const Text(
                          'Đăng nhập',
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
