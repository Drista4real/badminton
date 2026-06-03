import 'package:get/get.dart';

import '../../controllers/app/booking_controller.dart';
import '../../data/network/api_client.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/booking_repository.dart';
import '../../data/repository/court_repository.dart';

class BookingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(), permanent: true);
    }
    Get.lazyPut<CourtRepository>(
      () => CourtRepository(apiClient: Get.find<ApiClient>()),
    );
    Get.lazyPut<BookingRepository>(
      () => BookingRepository(apiClient: Get.find<ApiClient>()),
    );
    Get.lazyPut<BookingController>(
      () => BookingController(
        courtRepository: Get.find<CourtRepository>(),
        bookingRepository: Get.find<BookingRepository>(),
      ),
    );
  }
}
