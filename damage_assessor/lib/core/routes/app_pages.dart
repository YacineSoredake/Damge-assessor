import 'package:damage_assessor/features/history/bindings/history_binding.dart';
import 'package:damage_assessor/features/history/presentation/history_screen.dart';
import 'package:get/get.dart';
import '../../features/analysis/bindings/analysis_binding.dart';
import '../../features/analysis/presentation/analyzing_screen.dart';
import '../../features/analysis/presentation/results_screen.dart';
import '../../features/assessment/bindings/assessment_binding.dart';
import '../../features/assessment/presentation/capture_screen.dart';
import '../../features/assessment/presentation/vehicle_info_screen.dart';
import '../../features/auth/bindings/auth_binding.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/dashboard/bindings/dashboard_binding.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/subscription/bindings/subscription_binding.dart';
import '../../features/subscription/presentation/paywall_screen.dart';
import '../../features/report/bindings/report_binding.dart';
import '../../features/report/presentation/report_preview_screen.dart';
import '../middleware/auth_middleware.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.otpVerification,
      page: () => const OtpVerificationScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardScreen(),
      binding: DashboardBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.paywall,
      page: () => const PaywallScreen(),
      binding: SubscriptionBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.vehicleInfo,
      page: () => const VehicleInfoScreen(),
      binding: AssessmentBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.capture,
      page: () => const CaptureScreen(),
      // No binding here — reuses the CaptureController instance created
      // on vehicleInfo, since assessmentId must carry over between screens.
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.analyzing,
      page: () => const AnalyzingScreen(),
      binding: AnalysisBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.results,
      page: () => const ResultsScreen(),
      // No binding — reuses the AnalysisController instance from analyzing,
      // since the fetched result lives there.
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.reportPreview,
      page: () => const ReportPreviewScreen(),
      binding: ReportBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.history,
      page: () => const HistoryScreen(),
      binding: HistoryBinding(),
      middlewares: [AuthMiddleware()],
    ),
    // TODO: reportPreview (ReportBinding)
  ];
}
