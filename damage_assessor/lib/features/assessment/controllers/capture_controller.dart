import 'package:camera/camera.dart';
import 'package:get/get.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/routes/app_routes.dart';
import '../data/assessment_repository.dart';
import '../data/models/photo_model.dart';

enum CaptureScreenStatus { initializingCamera, ready, uploading, cameraError }

class CaptureController extends GetxController {
  final AssessmentRepository _repository;
  CaptureController(this._repository);

  // ── Vehicle info state ──────────────────────────────────────────
  final isCreatingAssessment = false.obs;
  final createAssessmentError = RxnString();
  int? assessmentId;
  static const maxCloseups =
      5; // matches the FastAPI service's closeup_1..closeup_5 limit

  // ── Camera / capture state ──────────────────────────────────────
  CameraController? cameraController;
  final status = CaptureScreenStatus.initializingCamera.obs;
  final cameraErrorMessage = RxnString();

  final currentStepIndex =
      0.obs; // index into requiredAngleSteps, until exhausted
  final capturedAngles = <PhotoType, CapturedPhoto>{}.obs;
  final closeups = <CapturedPhoto>[].obs;

  bool get allAnglesCaptured =>
      capturedAngles.length == requiredAngleSteps.length;
  PhotoType? get currentAngleStep =>
      currentStepIndex.value < requiredAngleSteps.length
          ? requiredAngleSteps[currentStepIndex.value]
          : null;

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }

  // ── Step 1: vehicle info → create assessment, then move to capture ──

  Future<void> submitVehicleInfo({
    required String plateNumber,
    String? vehicleMakeModel,
    String? clientReference,
    String? notes,
  }) async {
    if (plateNumber.trim().isEmpty) {
      createAssessmentError.value = 'Plate number is required.';
      return;
    }

    isCreatingAssessment.value = true;
    createAssessmentError.value = null;
    try {
      assessmentId = await _repository.createAssessment(
        plateNumber: plateNumber.trim(),
        vehicleMakeModel: vehicleMakeModel,
        clientReference: clientReference,
        notes: notes,
      );
      Get.toNamed(AppRoutes.capture);
    } catch (e) {
      if (e is SubscriptionRequiredFailure) {
        // Trial/subscription changed since the dashboard check — bounce
        // to paywall instead of showing a confusing form error.
        Get.offNamed(AppRoutes.paywall);
        return;
      }
      final failure = e is Failure ? e : const UnknownFailure();
      createAssessmentError.value = failure.message;
    } finally {
      isCreatingAssessment.value = false;
    }
  }

  // ── Step 2: camera lifecycle ─────────────────────────────────────

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        status.value = CaptureScreenStatus.cameraError;
        cameraErrorMessage.value = 'No camera found on this device.';
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await cameraController!.initialize();
      status.value = CaptureScreenStatus.ready;
    } on CameraException catch (e) {
      status.value = CaptureScreenStatus.cameraError;
      // Covers permission-denied specifically — distinct message so the
      // UI can deep-link to app settings per the spec's edge case.
      cameraErrorMessage.value = e.code == 'CameraAccessDenied'
          ? 'Camera permission denied. Enable it in your device settings to continue.'
          : 'Could not start the camera. Please try again.';
    }
  }

  // ── Step 3: capturing angle shots and close-ups ──────────────────

  Future<void> captureCurrentAngle() async {
    final step = currentAngleStep;
    if (step == null || cameraController == null) return;
    await _captureAndUpload(step);
    if (capturedAngles.containsKey(step)) {
      currentStepIndex.value++;
    }
  }

  Future<void> captureCloseup() async {
    if (cameraController == null) return;

    if (closeups.length >= maxCloseups) {
      Get.snackbar(
        'Limit reached',
        'Only the first $maxCloseups close-up photos can be analyzed. Delete one to add another.',
      );
      return;
    }

    await _captureAndUpload(PhotoType.closeup, isCloseup: true);
  }

  Future<void> _captureAndUpload(PhotoType type,
      {bool isCloseup = false}) async {
    if (assessmentId == null || cameraController == null) return;

    status.value = CaptureScreenStatus.uploading;
    try {
      final file = await cameraController!.takePicture().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const UnknownFailure(
              'Camera took too long to capture. Please try again.',
            ),
          );
      final photo = CapturedPhoto(type: type, localPath: file.path);

      final photoId = await _repository.uploadPhoto(
          assessmentId: assessmentId!, photo: photo);
      photo.uploaded = true;
      photo.photoId = photoId;

      if (isCloseup) {
        closeups.add(photo);
      } else {
        capturedAngles[type] = photo;
      }
    } catch (e) {
      // Per the spec: upload failures must not silently lose the photo.
      // Surface it so the UI can offer an explicit retry for this shot,
      // rather than the user assuming it worked and moving on.
      final failure = e is Failure ? e : const UnknownFailure();
      Get.snackbar('Upload failed', failure.message);
    } finally {
      status.value = CaptureScreenStatus.ready;
    }
  }

  void removeCloseup(CapturedPhoto photo) => closeups.remove(photo);

  /// Called from "Finish" — all 4 angles are required, close-ups are
  /// optional (per spec: a clean car with zero close-ups is still valid).
  void finishCapture() {
    if (!allAnglesCaptured) {
      Get.snackbar('Missing photos',
          'Please capture all 4 angle shots before continuing.');
      return;
    }
    Get.offNamed(AppRoutes.analyzing, arguments: assessmentId);
  }
}
