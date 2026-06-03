import 'package:get/get.dart';

import '../bindings/splash_binding.dart';
import '../bindings/app/auth_binding.dart';
import '../bindings/app/booking_binding.dart';
import '../bindings/app/history_binding.dart';
import '../bindings/app/home_binding.dart';
import '../bindings/app/notification_binding.dart';
import '../bindings/app/onboarding_binding.dart';
import '../bindings/app/payment_binding.dart';
import '../bindings/app/profile_binding.dart';
import '../bindings/app/wallet_binding.dart';
import '../middlewares/auth_middleware.dart';
import '../views/app/auth/login_screen.dart';
import '../views/app/auth/otp_screen.dart';
import '../views/app/auth/register_screen.dart';
import '../views/app/booking/booking_screen.dart';
import '../views/app/history/history_screen.dart';
import '../views/app/home/home_screen.dart';
import '../views/app/notification/notification_screen.dart';
import '../views/app/onboarding/onboarding_screen.dart';
import '../views/app/payment/payment_screen.dart';
import '../views/app/payment/payment_success_screen.dart';
import '../views/app/profile/change_password_screen.dart';
import '../views/app/profile/map_screen.dart';
import '../views/app/profile/profile_screen.dart';
import '../views/app/splash/splash_screen.dart';
import '../views/app/wallet/wallet_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.splash;

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingScreen(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.otp,
      page: () => const OtpScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.booking,
      page: () => const BookingScreen(),
      binding: BookingBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.payment,
      page: _paymentPage,
      binding: PaymentBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.paymentSuccess,
      page: _paymentSuccessPage,
      binding: BindingsBuilder(() {}),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.history,
      page: () {
        final args = _routeArgs;
        return HistoryScreen(initialIndex: args['initialIndex'] as int? ?? 0);
      },
      binding: HistoryBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.wallet,
      page: () => const WalletScreen(),
      binding: WalletBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.notification,
      page: () => const NotificationScreen(),
      binding: NotificationBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileScreen(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.map,
      page: () => const MapScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.changePassword,
      page: () => const ChangePasswordScreen(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
    ),
  ];

  static Map<String, dynamic> get _routeArgs {
    final args = Get.arguments;
    return args is Map<String, dynamic> ? args : <String, dynamic>{};
  }

  static PaymentScreen _paymentPage() {
    final args = _routeArgs;
    return PaymentScreen(
      courtName: args['courtName'] as String? ?? '',
      price: (args['price'] as num?)?.toDouble() ?? 0,
      date: args['date'] as String? ?? '',
      time: args['time'] as String? ?? '',
      isFixed: args['isFixed'] as bool? ?? false,
      fixedDuration: args['fixedDuration'] as String?,
      orderId: args['orderId'] as String?,
      bookingIds: args['bookingIds'] is List
          ? (args['bookingIds'] as List).map((item) => item.toString()).toList()
          : const <String>[],
    );
  }

  static PaymentSuccessScreen _paymentSuccessPage() {
    final args = _routeArgs;
    return PaymentSuccessScreen(
      courtName: args['courtName'] as String? ?? '',
      price: (args['price'] as num?)?.toDouble() ?? 0,
      date: args['date'] as String? ?? '',
      time: args['time'] as String? ?? '',
      bookingCode: args['bookingCode'] as String? ?? '',
    );
  }
}
