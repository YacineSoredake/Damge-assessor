import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/theme.dart';
import '../controllers/analysis_controller.dart';

class AnalyzingScreen extends GetView<AnalysisController> {
  const AnalyzingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // assessmentId passed as a route argument from CaptureController.finishCapture().
    final assessmentId = Get.arguments as int?;
    if (assessmentId != null && controller.assessmentId == null) {
      controller.start(assessmentId);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Obx(() {
              switch (controller.status.value) {
                case AnalysisScreenStatus.starting:
                case AnalysisScreenStatus.polling:
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        controller.progressText.value,
                        style: const TextStyle(fontSize: 16, color: AppColors.navy, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This usually takes 15–45 seconds.',
                        style: TextStyle(color: AppColors.slate, fontSize: 13),
                      ),
                    ],
                  );

                case AnalysisScreenStatus.failed:
                  return _RetryState(
                    message: 'Analysis failed. This can happen due to a temporary issue.',
                    onRetry: controller.retry,
                  );

                case AnalysisScreenStatus.error:
                  return _RetryState(
                    message: controller.errorMessage.value ?? 'Something went wrong.',
                    onRetry: controller.retry,
                  );

                case AnalysisScreenStatus.done:
                  return const SizedBox.shrink(); // navigation already happened
              }
            }),
          ),
        ),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RetryState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.red, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
