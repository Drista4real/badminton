import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/court_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/court_repository.dart';
import '../../data/repository/notification_repository.dart';
import '../../data/repository/user_repository.dart';
import '../../routes/app_routes.dart';
import '../../utils/currency_format.dart';
import '../../utils/date_format.dart';

class HomeController extends GetxController {
  HomeController({
    required CourtRepository courtRepository,
    required NotificationRepository notificationRepository,
    required UserRepository userRepository,
    required AuthRepository authRepository,
  }) : _courtRepository = courtRepository,
       _notificationRepository = notificationRepository,
       _userRepository = userRepository,
       _authRepository = authRepository;

  final CourtRepository _courtRepository;
  final NotificationRepository _notificationRepository;
  final UserRepository _userRepository;
  final AuthRepository _authRepository;

  final selectedNavIndex = 0.obs;
  final selectedDayIndex = 0.obs;
  final selectedPriceBandIndex = 0.obs;
  final isLoadingCourts = true.obs;
  final errorMessage = ''.obs;
  final courts = <CourtModel>[].obs;
  final user = Rxn<UserModel>();
  final unreadNotificationCount = 0.obs;

  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription? _notificationsSub;

  @override
  void onInit() {
    super.onInit();
    refreshCourts();
    _watchUser();
    _watchUnreadNotifications();
  }

  void selectDay(int index) {
    selectedDayIndex.value = index;
    selectedPriceBandIndex.value = 0;
  }

  void selectPriceBand(int index) {
    if (index < 0 || index >= priceBands.length) {
      return;
    }
    selectedPriceBandIndex.value = index;
  }

  void onBottomNavTap(int index) {
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
        selectedNavIndex.value = index;
    }
  }

  String get greetingName {
    final profileName = user.value?.fullName.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    final displayName = _authRepository.currentDisplayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = _authRepository.currentEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'home.defaultName'.tr;
  }

  String get todayLabel {
    return DateFormatUtils.vietnameseWeekdayDate(DateTime.now());
  }

  List<HomePriceBand> get priceBands {
    return selectedDayIndex.value == 0
        ? HomePriceBand.weekdayBands
        : HomePriceBand.weekendBands;
  }

  HomePriceBand get selectedPriceBand {
    final bands = priceBands;
    final selectedIndex = selectedPriceBandIndex.value;
    if (selectedIndex >= 0 && selectedIndex < bands.length) {
      return bands[selectedIndex];
    }
    return bands.first;
  }

  List<HomePriceRow> get priceRows {
    final band = selectedPriceBand;
    return courts
        .map(
          (court) => HomePriceRow(
            courtLabel: _courtLabel(court),
            description: _courtDescription(court),
            fixedPrice: _fixedPrice(court, band),
            accountPrice: _accountPrice(court, band),
            guestPrice: _guestPrice(court, band),
          ),
        )
        .toList();
  }

  String formatMoney(num value) {
    if (value <= 0) {
      return '--';
    }

    return CurrencyFormat.number(value);
  }

  Future<void> refreshCourts() async {
    isLoadingCourts.value = true;
    errorMessage.value = '';

    try {
      final items = await _courtRepository.fetchActiveCourts();
      courts.assignAll(items);
      errorMessage.value = '';
    } on CourtApiException catch (error) {
      courts.clear();
      errorMessage.value = error.message;
    } catch (_) {
      courts.clear();
      errorMessage.value = 'Không tải được bảng giá sân từ backend.';
    } finally {
      isLoadingCourts.value = false;
    }
  }

  void _watchUser() {
    final userId = _authRepository.currentUserId;
    if (userId == null || userId.isEmpty) {
      user.value = null;
      return;
    }

    _userSub = _userRepository
        .watchUserProfile(userId)
        .listen(
          (profile) {
            user.value = profile;
          },
          onError: (_) {
            user.value = null;
          },
        );
  }

  void _watchUnreadNotifications() {
    final userId = _authRepository.currentUserId;
    if (userId == null || userId.isEmpty) {
      unreadNotificationCount.value = 0;
      return;
    }

    _notificationsSub = _notificationRepository
        .watchUserNotifications(userId)
        .listen(
          (items) {
            unreadNotificationCount.value = items
                .where((item) => !item.isRead)
                .length;
          },
          onError: (_) {
            unreadNotificationCount.value = 0;
          },
        );
  }

  String _courtLabel(CourtModel court) {
    if (court.name.isNotEmpty) {
      return court.name;
    }
    if (court.code.isNotEmpty) {
      return 'Sân ${court.code}';
    }
    return court.id;
  }

  String _courtDescription(CourtModel court) {
    final parts = <String>[];
    if (court.code.isNotEmpty) {
      parts.add(court.code);
    }
    if (court.surfaceType.isNotEmpty) {
      parts.add(court.surfaceType);
    }
    return parts.isEmpty ? 'Đang hoạt động' : parts.join(' - ');
  }

  double _fixedPrice(CourtModel court, HomePriceBand band) {
    return _firstPositive([
      _priceByKeys(court, [
        '${band.keyPrefix}.fixed',
        '${band.dayPrefix}.fixed',
        'fixed',
        'fixedSchedule',
        'fixedSchedulePrice',
      ]),
      court.fixedSchedulePrice,
      court.basePrice,
    ]);
  }

  double _accountPrice(CourtModel court, HomePriceBand band) {
    return _firstPositive([
      _priceByKeys(court, [
        '${band.keyPrefix}.account',
        '${band.dayPrefix}.account',
        '${band.dayPrefix}Account',
      ]),
      court.basePrice,
      _averageHourlyPrice(court),
    ]);
  }

  double _guestPrice(CourtModel court, HomePriceBand band) {
    return _firstPositive([
      _priceByKeys(court, [
        '${band.keyPrefix}.guest',
        '${band.dayPrefix}.guest',
        '${band.dayPrefix}Guest',
      ]),
      court.peakPrice,
      court.basePrice,
      _averageHourlyPrice(court),
    ]);
  }

  double _priceByKeys(CourtModel court, List<String> keys) {
    for (final key in keys) {
      final value = court.hourlyPrices[key];
      if (value != null && value > 0) {
        return value;
      }
    }
    return 0;
  }

  double _averageHourlyPrice(CourtModel court) {
    final values = court.hourlyPrices.values.where((value) => value > 0);
    if (values.isEmpty) {
      return 0;
    }

    final total = values.fold<double>(0, (sum, value) => sum + value);
    return total / values.length;
  }

  double _firstPositive(List<double> values) {
    for (final value in values) {
      if (value > 0) {
        return value;
      }
    }
    return 0;
  }

  @override
  void onClose() {
    _userSub?.cancel();
    _notificationsSub?.cancel();
    super.onClose();
  }
}

class HomePriceBand {
  const HomePriceBand({
    required this.dayPrefix,
    required this.keyPrefix,
    required this.timeLabel,
  });

  final String dayPrefix;
  final String keyPrefix;
  final String timeLabel;

  static const weekdayBands = <HomePriceBand>[
    HomePriceBand(
      dayPrefix: 'weekday',
      keyPrefix: 'weekday.morning',
      timeLabel: '05:00 - 09:00',
    ),
    HomePriceBand(
      dayPrefix: 'weekday',
      keyPrefix: 'weekday.base',
      timeLabel: '09:00 - 16:00',
    ),
    HomePriceBand(
      dayPrefix: 'weekday',
      keyPrefix: 'weekday.peak',
      timeLabel: '16:00 - 22:00',
    ),
    HomePriceBand(
      dayPrefix: 'weekday',
      keyPrefix: 'late',
      timeLabel: '22:00 - 24:00',
    ),
  ];

  static const weekendBands = <HomePriceBand>[
    HomePriceBand(
      dayPrefix: 'weekend',
      keyPrefix: 'weekend.base',
      timeLabel: '05:00 - 16:00',
    ),
    HomePriceBand(
      dayPrefix: 'weekend',
      keyPrefix: 'weekend.peak',
      timeLabel: '16:00 - 22:00',
    ),
    HomePriceBand(
      dayPrefix: 'weekend',
      keyPrefix: 'late',
      timeLabel: '22:00 - 24:00',
    ),
  ];
}

class HomePriceRow {
  const HomePriceRow({
    required this.courtLabel,
    required this.description,
    required this.fixedPrice,
    required this.accountPrice,
    required this.guestPrice,
  });

  final String courtLabel;
  final String description;
  final double fixedPrice;
  final double accountPrice;
  final double guestPrice;
}
