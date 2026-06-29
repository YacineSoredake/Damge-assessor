import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/theme.dart';
import '../controllers/report_controller.dart';

class ReportPreviewScreen extends GetView<ReportController> {
  const ReportPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final assessmentId = Get.arguments as int;
    if (controller.localPdfPath.value == null && controller.status.value == ReportStatus.generating) {
      controller.generate(assessmentId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        actions: [
          Obx(() {
            if (controller.status.value != ReportStatus.ready) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => Share.shareXFiles([XFile(controller.localPdfPath.value!)]),
            );
          }),
        ],
      ),
      body: Obx(() {
        switch (controller.status.value) {
          case ReportStatus.generating:
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating report…'),
                ],
              ),
            );
          case ReportStatus.error:
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.red, size: 40),
                    const SizedBox(height: 12),
                    Text(controller.errorMessage.value ?? 'Could not generate report.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => controller.retry(assessmentId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          case ReportStatus.ready:
            return PDFView(filePath: controller.localPdfPath.value!);
        }
      }),
    );
  }
}