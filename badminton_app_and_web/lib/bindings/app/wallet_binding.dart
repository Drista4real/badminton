import 'package:get/get.dart';

import '../../controllers/app/wallet_controller.dart';
import '../../data/network/api_client.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/wallet_repository.dart';

class WalletBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(), permanent: true);
    }
    Get.lazyPut<WalletRepository>(
      () => WalletRepository(apiClient: Get.find<ApiClient>()),
    );
    Get.lazyPut<WalletController>(
      () => WalletController(
        walletRepository: Get.find<WalletRepository>(),
        authRepository: Get.find<AuthRepository>(),
      ),
    );
  }
}
