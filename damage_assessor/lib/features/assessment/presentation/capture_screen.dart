import 'package:camera/camera.dart';
import 'package:damage_assessor/features/assessment/data/models/photo_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/theme.dart';
import '../controllers/capture_controller.dart';
import 'widgets/capture_progress_bar.dart';

class CaptureScreen extends GetView<CaptureController> {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Camera init kicked off once when the screen is first built.
    if (controller.status.value == CaptureScreenStatus.initializingCamera &&
        controller.cameraController == null) {
      controller.initCamera();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          switch (controller.status.value) {
            case CaptureScreenStatus.initializingCamera:
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));

            case CaptureScreenStatus.cameraError:
              return _CameraErrorState(
                  message:
                      controller.cameraErrorMessage.value ?? 'Camera error.');

            case CaptureScreenStatus.ready:
            case CaptureScreenStatus.uploading:
              return _CameraReadyView(
                  uploading:
                      controller.status.value == CaptureScreenStatus.uploading);
          }
        }),
      ),
    );
  }
}

class _CameraErrorState extends StatelessWidget {
  final String message;
  const _CameraErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Get.find<CaptureController>().initCamera(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraReadyView extends GetView<CaptureController> {
  final bool uploading;
  const _CameraReadyView({required this.uploading});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller.cameraController != null)
          CameraPreview(controller.cameraController!),

        // Top: progress bar for the 4 required angles.
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: CaptureProgressBar(capturedAngles: controller.capturedAngles),
        ),

        // Bottom: current step prompt + capture button, or close-up mode
        // once all 4 angles are done.
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Obx(() {
            if (!controller.allAnglesCaptured) {
              final step = controller.currentAngleStep;
              return Column(
                children: [
                  Text(
                    'Capture: ${step?.label ?? ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _ShutterButton(
                    uploading: uploading,
                    onTap: controller.captureCurrentAngle,
                  ),
                ],
              );
            }

            // All 4 angles done — close-up mode.
            return Column(
              children: [
                Text(
                  '${controller.closeups.length}/${CaptureController.maxCloseups} close-up(s) added',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _ShutterButton(
                    uploading: uploading, onTap: controller.captureCloseup),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: controller.finishCapture,
                  child: const Text('Finish assessment',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final bool uploading;
  final VoidCallback onTap;
  const _ShutterButton({required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: AppColors.accent, width: 4),
        ),
        child: uploading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              )
            : null,
      ),
    );
  }
}
