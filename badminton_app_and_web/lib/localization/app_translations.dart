import 'package:get/get.dart';

import 'en_us.dart';
import 'vi_vn.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'en_US': enUs, 'vi_VN': viVn};
}
