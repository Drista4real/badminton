import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/court_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/court_repository.dart';
import '../../data/repository/user_repository.dart';
import '../../routes/app_routes.dart';
import '../../utils/currency_format.dart';
import '../../utils/date_format.dart';

class HomeController extends GetxController {
  HomeController({
    required CourtRepository courtRepository,
    required UserRepository userRepository,
    required AuthRepository authRepository,
  }) : _courtRepository = courtRepository,
       _userRepository = userRepository,
       _authRepository = authRepository;

  final CourtRepository _courtRepository;
  final UserRepository _userRepository;
  final AuthRepository _authRepository;

  final selectedNavIndex = 0.obs;
  final selectedDayIndex = 0.obs;
  final isLoadingCourts = true.obs;
  final errorMessage = ''.obs;
  final courts = <CourtModel>[].obs;
  final user = Rxn<UserModel>();

  StreamSubscription<UserModel?>? _userSub;

  @override
  void onInit() {
    super.onInit();
    refreshCourts();
    _watchUser();
  }

  void selectDay(int index) {
    selectedDayIndex.value = index;
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

  List<HomePriceRow> get priceRows {
    return courts.map((court) {
      return HomePriceRow(
        courtLabel: _courtLabel(court),
        description: _courtDescription(court),
        fixedPrice: _fixedPrice(court),
        accountPrice: _accountPrice(court),
        guestPrice: _guestPrice(court),
      );
    }).toList();
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

  double _fixedPrice(CourtModel court) {
    return _firstPositive([
      court.fixedSchedulePrice,
      _priceByKeys(court, ['fixed', 'fixedSchedule', 'fixedSchedulePrice']),
      court.basePrice,
    ]);
  }

  double _accountPrice(CourtModel court) {
    final dayPrefix = selectedDayIndex.value == 0 ? 'weekday' : 'weekend';
    return _firstPositive([
      _priceByKeys(court, ['$dayPrefix.account', '${dayPrefix}Account']),
      _priceByKeys(court, ['$dayPrefix.base', '${dayPrefix}Base']),
      court.basePrice,
      _averageHourlyPrice(court),
    ]);
  }

  double _guestPrice(CourtModel court) {
    final dayPrefix = selectedDayIndex.value == 0 ? 'weekday' : 'weekend';
    return _firstPositive([
      _priceByKeys(court, ['$dayPrefix.guest', '${dayPrefix}Guest']),
      _priceByKeys(court, ['$dayPrefix.peak', '${dayPrefix}Peak']),
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
    super.onClose();
  }
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
