import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton/apps/badminton_app.dart';
import 'package:badminton/controllers/app/app_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Firebase.initializeApp();
    Get.testMode = true;
    Get.put<AppSettingsController>(
      AppSettingsController(
        initialDarkMode: false,
        initialLocale: AppSettingsController.vietnameseLocale,
      ),
      permanent: true,
    );
  });

  tearDown(Get.reset);

  testWidgets('App renders splash smoke test', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BadmintonApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.sports_tennis_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
  });
}
