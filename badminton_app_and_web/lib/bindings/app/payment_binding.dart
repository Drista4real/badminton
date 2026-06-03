import 'package:get/get.dart';

import '../../controllers/app/payment_controller.dart';
import '../../data/network/api_client.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/payment_repository.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(), permanent: true);
    }
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    Get.lazyPut<PaymentRepository>(
      () => PaymentRepository(apiClient: Get.find<ApiClient>()),
    );
    Get.lazyPut<PaymentController>(
      () => PaymentController(
        paymentRepository: Get.find<PaymentRepository>(),
        authRepository: Get.find<AuthRepository>(),
      ),
    );
  }
}
