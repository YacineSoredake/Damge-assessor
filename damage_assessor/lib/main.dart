import 'package:damage_assessor/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/theme.dart';
import 'core/middleware/auth_middleware.dart';
import 'core/network/api_client.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Core singletons available app-wide before runApp.
  Get.put(ApiClient(), permanent: true);
  final session = Get.put(SessionState(), permanent: true);
  await session.hydrate(); // sync read of stored token presence

  runApp(DamageAssessorApp(
      initialRoute: session.hasToken ? AppRoutes.dashboard : AppRoutes.login));
}

class DamageAssessorApp extends StatelessWidget {
  final String initialRoute;
  const DamageAssessorApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AutoVerifDz — Damage Assessor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
    );
  }
}
