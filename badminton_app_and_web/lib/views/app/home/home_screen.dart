import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../commons/styles/app_colors.dart';
import '../../../controllers/app/home_controller.dart';
import '../../../routes/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double _bottomNavReservedHeight = 96;
  static const double _priceCourtColumnWidth = 96;

  @override
  Widget build(BuildContext context) {
    final controller = _findController();
    final theme = Theme.of(context);

    return SizedBox.expand(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom:
                        _bottomNavReservedHeight +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    _buildHeader(context, controller),
                    const SizedBox(height: 12),
                    _buildBanner(controller),
                    const SizedBox(height: 20),
                    _buildPriceSection(controller),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNav(context, controller),
            ),
          ],
        ),
      ),
    );
  }

  HomeController? _findController() {
    try {
      return Get.find<HomeController>();
    } catch (_) {
      return null;
    }
  }

  Widget _buildHeader(BuildContext context, HomeController? controller) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.profile),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: controller == null
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : Obx(() => _buildAvatarWidget(controller.avatarUrl)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: controller == null
                ? _HeaderText(name: 'bạn', dateLabel: _todayLabel())
                : Obx(
                    () => _HeaderText(
                      name: controller.greetingName,
                      dateLabel: controller.todayLabel,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          _buildNotificationButton(controller),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(HomeController? controller) {
    Widget button({required int unreadCount}) {
      return GestureDetector(
        onTap: () => _onBottomNavTap(3, controller),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.red, width: 1.5),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (controller == null) {
      return button(unreadCount: 0);
    }

    return Obx(
      () => button(unreadCount: controller.unreadNotificationCount.value),
    );
  }

  Widget _buildBanner(HomeController? controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            height: 188,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0B7D77),
                  Color(0xFF0DBDB6),
                  Color(0xFF12D9D0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: -40,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ShuttleGo Badminton',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'home.bannerTitle'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _onBottomNavTap(1, controller),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'home.bookNow'.tr,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection(HomeController? controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'home.priceTitle'.tr,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleBtn('T2 - T6', 0, controller),
                    _buildToggleBtn('T7 - CN', 1, controller),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTimeBandTabs(controller),
          const SizedBox(height: 12),
          _buildPriceHeader(),
          const SizedBox(height: 8),
          if (controller == null)
            _buildEmptyState('Đang tải dữ liệu trang chủ.')
          else
            Obx(() => _buildPriceBody(controller)),
        ],
      ),
    );
  }

  Widget _buildPriceBody(HomeController controller) {
    try {
      if (controller.isLoadingCourts.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (controller.errorMessage.value.isNotEmpty) {
        return _buildEmptyState(controller.errorMessage.value);
      }

      final rows = controller.priceRows;
      if (rows.isEmpty) {
        return _buildEmptyState('Chưa có dữ liệu bảng giá sân.');
      }

      return Column(children: rows.map(_buildPriceRow).toList(growable: false));
    } catch (_) {
      return _buildEmptyState('Không thể hiển thị bảng giá sân.');
    }
  }

  Widget _buildPriceHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _priceCourtColumnWidth,
            child: Text(
              'home.court'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _headerLabel('home.fixed'.tr)),
                Expanded(child: _headerLabel('home.account'.tr)),
                Expanded(child: _headerLabel('home.guest'.tr)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerLabel(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildToggleBtn(String label, int index, HomeController? controller) {
    if (controller == null) {
      return _ToggleButton(label: label, isSelected: index == 0, onTap: null);
    }

    return Obx(
      () => _ToggleButton(
        label: label,
        isSelected: controller.selectedDayIndex.value == index,
        onTap: () => controller.selectDay(index),
      ),
    );
  }

  Widget _buildTimeBandTabs(HomeController? controller) {
    if (controller == null) {
      return _TimeBandTabs(
        bands: HomePriceBand.weekdayBands,
        selectedIndex: 0,
        onTap: null,
      );
    }

    return Obx(
      () => _TimeBandTabs(
        bands: controller.priceBands,
        selectedIndex: controller.selectedPriceBandIndex.value,
        onTap: controller.selectPriceBand,
      ),
    );
  }

  Widget _buildPriceRow(HomePriceRow row) {
    final colors = [
      const Color(0xFF2E7D32),
      const Color(0xFF0B7D77),
      const Color(0xFFE65100),
    ];
    final prices = [row.fixedPrice, row.accountPrice, row.guestPrice];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: _priceCourtColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.courtLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    row.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatMoney(controller: null, value: prices[index]),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors[index],
                          ),
                        ),
                      ),
                      const Text(
                        'VNĐ',
                        style: TextStyle(fontSize: 9, color: AppColors.grey),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney({
    required HomeController? controller,
    required num value,
  }) {
    if (controller != null) return controller.formatMoney(value);
    if (value <= 0) return '--';
    return value.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grey, fontSize: 13),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, HomeController? controller) {
    final items = <Map<String, Object>>[
      {'icon': Icons.home_rounded, 'label': 'nav.home'},
      {'icon': Icons.sports_tennis_rounded, 'label': 'nav.booking'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'nav.wallet'},
      {'icon': Icons.notifications_rounded, 'label': 'nav.notification'},
      {'icon': Icons.person_rounded, 'label': 'nav.profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: controller == null
              ? _BottomNavRow(
                  items: items,
                  selectedIndex: 0,
                  onTap: (index) => _onBottomNavTap(index, null),
                )
              : Obx(
                  () => _BottomNavRow(
                    items: items,
                    selectedIndex: controller.selectedNavIndex.value,
                    onTap: (index) => _onBottomNavTap(index, controller),
                  ),
                ),
        ),
      ),
    );
  }

  void _onBottomNavTap(int index, HomeController? controller) {
    if (controller != null) {
      controller.onBottomNavTap(index);
      return;
    }

    switch (index) {
      case 1:
        Get.toNamed(AppRoutes.booking);
        return;
      case 2:
        Get.toNamed(AppRoutes.wallet);
        return;
      case 3:
        Get.toNamed(AppRoutes.notification);
        return;
      case 4:
        Get.toNamed(AppRoutes.profile);
        return;
      default:
        return;
    }
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    return '${weekdays[now.weekday - 1]}, $day/$month/${now.year}';
  }

  Widget _buildAvatarWidget(String? avatarUrl) {
    if (avatarUrl == null) {
      return const Icon(Icons.person, color: Colors.white, size: 24);
    }

    if (avatarUrl.startsWith('data:image/')) {
      final commaIndex = avatarUrl.indexOf(',');
      if (commaIndex > 0) {
        try {
          return Image.memory(
            base64Decode(avatarUrl.substring(commaIndex + 1)),
            fit: BoxFit.cover,
            width: 44,
            height: 44,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.person, color: Colors.white, size: 24),
          );
        } catch (_) {
          return const Icon(Icons.person, color: Colors.white, size: 24);
        }
      }
    }

    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      width: 44,
      height: 44,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.person, color: Colors.white, size: 24),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({required this.name, required this.dateLabel});

  final String name;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'home.greeting'.trParams({'name': name}),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        Text(
          dateLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.grey),
        ),
      ],
    );
  }
}

class _TimeBandTabs extends StatelessWidget {
  const _TimeBandTabs({
    required this.bands,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<HomePriceBand> bands;
  final int selectedIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            bands.length,
            (index) => _ToggleButton(
              label: bands[index].timeLabel,
              isSelected: selectedIndex == index,
              onTap: onTap == null ? null : () => onTap!(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.grey,
          ),
        ),
      ),
    );
  }
}

class _BottomNavRow extends StatelessWidget {
  const _BottomNavRow({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<Map<String, Object>> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(items.length, (index) {
        final isSelected = selectedIndex == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(index),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[index]['icon'] as IconData,
                      color: isSelected ? AppColors.primary : AppColors.grey,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        (items[index]['label'] as String).tr,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.grey,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
