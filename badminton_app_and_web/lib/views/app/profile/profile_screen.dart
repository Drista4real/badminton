import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/styles/app_colors.dart';
import '../../../controllers/app/profile_controller.dart';
import '../../../routes/app_routes.dart';

class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  static const _selectedNavIndex = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: _buildBottomNav(context),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildPersonalInfo(context),
                const SizedBox(height: 12),
                _buildActivities(context),
                const SizedBox(height: 12),
                _buildPreferences(context),
                const SizedBox(height: 12),
                _buildSecurity(context),
                const SizedBox(height: 12),
                _buildLogout(context),
                const SizedBox(height: 20),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = _cardColor(context);
    final textColor = _textColor(context);

    return Container(
      width: double.infinity,
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(child: _buildAvatar()),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cardColor, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            controller.fullName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            controller.emailAddress.isEmpty
                ? 'profile.emailNotUpdated'.tr
                : controller.emailAddress,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _mutedTextColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = controller.avatarUrl;
    if (avatarUrl == null) {
      return const Icon(Icons.person_rounded, color: Colors.white, size: 44);
    }

    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.person_rounded, color: Colors.white, size: 44);
      },
    );
  }

  Widget _buildPersonalInfo(BuildContext context) {
    return _buildSection(
      context,
      title: 'profile.personalInfo'.tr,
      children: [
        _buildEditableRow(
          context,
          Icons.person_outline_rounded,
          'profile.fullName'.tr,
          controller.fullName,
          onTap: () => _showEditProfileDialog(context),
        ),
        _buildDivider(),
        _buildEditableRow(
          context,
          Icons.phone_outlined,
          'profile.phone'.tr,
          controller.phoneNumber,
          onTap: () => _showEditProfileDialog(context),
        ),
        _buildDivider(),
        _buildEditableRow(
          context,
          Icons.email_outlined,
          'profile.email'.tr,
          controller.emailAddress.isEmpty
              ? 'profile.notUpdated'.tr
              : controller.emailAddress,
          onTap: () => _showEditProfileDialog(context),
        ),
      ],
    );
  }

  Widget _buildActivities(BuildContext context) {
    return _buildSection(
      context,
      title: 'profile.myActivities'.tr,
      children: [
        _buildNavRow(
          context,
          Icons.history_rounded,
          'profile.bookingHistory'.tr,
          onTap: () => Get.toNamed(AppRoutes.history),
        ),
        _buildDivider(),
        _buildNavRow(
          context,
          Icons.location_on_outlined,
          'profile.mapLocation'.tr,
          onTap: controller.openCourtLocation,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildPreferences(BuildContext context) {
    return _buildSection(
      context,
      title: 'profile.preferences'.tr,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildLeadingIcon(context, Icons.dark_mode_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'profile.darkMode'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor(context),
                  ),
                ),
              ),
              Obx(
                () => CupertinoSwitch(
                  value: controller.isDarkMode.value,
                  activeTrackColor: AppColors.primary,
                  onChanged: controller.toggleDarkMode,
                ),
              ),
            ],
          ),
        ),
        _buildDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildLeadingIcon(context, Icons.language_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'profile.language'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor(context),
                  ),
                ),
              ),
              Obx(
                () => CupertinoSlidingSegmentedControl<String>(
                  groupValue: controller.selectedLanguageCode.value,
                  children: {
                    'vi': Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('profile.vietnameseShort'.tr),
                    ),
                    'en': Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('profile.englishShort'.tr),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) controller.changeLanguage(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurity(BuildContext context) {
    return _buildSection(
      context,
      title: 'profile.security'.tr,
      children: [
        _buildNavRow(
          context,
          Icons.lock_outline_rounded,
          'profile.changePassword'.tr,
          onTap: () => Get.toNamed(AppRoutes.changePassword),
        ),
      ],
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showLogoutDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _cardColor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _shadow(context),
          ),
          child: Text(
            'profile.logout'.tr,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEF5350),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _mutedTextColor(context),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _cardColor(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _shadow(context),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildLeadingIcon(context, icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _mutedTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildNavRow(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onTap,
    int maxLines = 1,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildLeadingIcon(context, icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textColor(context),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 18),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 66,
      endIndent: 16,
      color: Color(0xFFE8EEEE),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    controller.syncProfileForm();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'profile.editInfo'.tr,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(
                  controller: controller.profileNameController,
                  label: 'profile.fullName'.tr,
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _buildDialogField(
                  controller: controller.profilePhoneController,
                  label: 'profile.phone'.tr,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _buildDialogField(
                  controller: controller.profileEmailController,
                  label: 'profile.email'.tr,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr),
            ),
            Obx(
              () => ElevatedButton(
                onPressed: controller.isSavingProfile.value
                    ? null
                    : () async {
                        final password = await _showCurrentPasswordDialog(
                          dialogContext,
                        );
                        if (password == null) return;

                        final saved = await controller.saveProfileChanges(
                          password,
                        );
                        if (saved && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: controller.isSavingProfile.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('common.save'.tr),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.done,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }

  Future<String?> _showCurrentPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    var obscurePassword = true;

    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'profile.passwordConfirmTitle'.tr,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'profile.currentPassword'.tr,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  Navigator.pop(dialogContext, passwordController.text);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('common.cancel'.tr),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, passwordController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('common.confirm'.tr),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    return password;
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'profile.logout'.tr,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'profile.logoutConfirm'.tr,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'profile.logout'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'nav.home'},
      {'icon': Icons.sports_tennis_rounded, 'label': 'nav.booking'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'nav.wallet'},
      {'icon': Icons.notifications_rounded, 'label': 'nav.notification'},
      {'icon': Icons.person_rounded, 'label': 'nav.profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cardColor(context),
        boxShadow: _shadow(context),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = _selectedNavIndex == index;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _onBottomNavTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
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
                      Text(
                        (items[index]['label'] as String).tr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? AppColors.primary
                              : _mutedTextColor(context),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.home);
        return;
      case 1:
        Get.offNamed(AppRoutes.booking);
        return;
      case 2:
        Get.offNamed(AppRoutes.wallet);
        return;
      case 3:
        Get.offNamed(AppRoutes.notification);
        return;
      default:
        return;
    }
  }

  Color _cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF18201F)
        : Colors.white;
  }

  Color _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFEAF3F1)
        : AppColors.black;
  }

  Color _mutedTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB7C7C4)
        : AppColors.grey;
  }

  List<BoxShadow> _shadow(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return const [];
    }

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
