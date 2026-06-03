import 'package:get/get.dart';

import '../../controllers/app/history_controller.dart';
import '../../data/network/api_client.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/booking_repository.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(), permanent: true);
    }
    if (!Get.isRegistered<BookingRepository>()) {
      Get.lazyPut<BookingRepository>(
        () => BookingRepository(apiClient: Get.find<ApiClient>()),
      );
    }

    Get.lazyPut<HistoryController>(
      () => HistoryController(
        bookingRepository: Get.find<BookingRepository>(),
        authRepository: Get.find<AuthRepository>(),
      ),
    );
  }
}
