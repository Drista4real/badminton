// ===============================
// FILE: lib/views/app/onboarding/onboarding_screen.dart
// ===============================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import 'onboarding_controller.dart';
import 'onboarding_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = Get.find<OnboardingController>();
  final PageController pageController = PageController();

  final List<OnboardingModel> onboardingList = [
    OnboardingModel(
      image: 'assets/images/onboarding1.jpg',
      title: 'Đặt Sân\nSiêu Nhanh',
      description: 'Tìm và đặt sân cầu lông\ngần bạn chỉ trong vài giây',
    ),
    OnboardingModel(
      image: 'assets/images/onboarding2.jpg',
      title: 'Tham Gia\nGiải Đấu',
      description: 'Kết nối người chơi và\ntham gia các giải đấu hấp dẫn.',
    ),
    OnboardingModel(
      image: 'assets/images/onboarding3.jpg',
      title: 'Xây Dựng\nCộng Đồng',
      description: 'Kết nối, tập luyện và\ncùng nhau nâng cao kỹ năng.',
    ),
  ];

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView.builder(
        controller: pageController,
        onPageChanged: controller.changePage,
        itemCount: onboardingList.length,
        itemBuilder: (context, index) {
          final item = onboardingList[index];
          return _OnboardingPage(
            item: item,
            index: index,
            total: onboardingList.length,
            controller: controller,
            pageController: pageController,
          );
        },
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingModel item;
  final int index;
  final int total;
  final OnboardingController controller;
  final PageController pageController;

  const _OnboardingPage({
    required this.item,
    required this.index,
    required this.total,
    required this.controller,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageHeight = size.height * 0.60;

    return Stack(
      children: [
        // ── 1. Ảnh tràn viền ở phía trên với hiệu ứng mờ dần ở dưới
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: imageHeight,
          child: ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.transparent],
                stops: [0.65, 0.95], // Bắt đầu mờ từ 65% đến 95% của ảnh
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              item.image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // ── 2. Nội dung text + dot indicators + button ở phía dưới
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: size.height * 0.40,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                // Mô tả
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.grey,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 24),

                // Dot indicators
                Row(
                  children: List.generate(total, (dotIndex) {
                    return Obx(
                      () => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: controller.currentPage.value == dotIndex
                            ? 24
                            : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: controller.currentPage.value == dotIndex
                              ? AppColors.secondary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }),
                ),

                const Spacer(),

                // Nút Tiếp theo / Bắt đầu (Thiết kế dạng viên thuốc đen)
                GestureDetector(
                  onTap: () {
                    if (index == total - 1) {
                      controller.completeOnboarding();
                    } else {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(38),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Trái: Hình tròn xanh chứa icon vợt/thể thao
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports_tennis_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),

                        // Giữa: Chữ trắng
                        Text(
                          index == total - 1 ? 'Bắt Đầu' : 'Tiếp Theo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),

                        // Phải: Hình tròn trắng chứa mũi tên đen
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 3. Nút back + skip nổi lên trên ảnh
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (index > 0)
                    GestureDetector(
                      onTap: () => pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      ),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(217),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(13),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.black,
                          size: 18,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 42),

                  if (index < total - 1)
                    GestureDetector(
                      onTap: controller.completeOnboarding,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(217),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(13),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Bỏ qua',
                          style: TextStyle(
                            color: AppColors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 42),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
