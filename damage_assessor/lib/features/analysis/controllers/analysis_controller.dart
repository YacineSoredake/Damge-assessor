import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/routes/app_routes.dart';
import '../data/analysis_repository.dart';
import '../data/models/result_model.dart';

enum AnalysisScreenStatus { starting, polling, done, failed, error }

class AnalysisController extends GetxController {
  final AnalysisRepository _repository;
  AnalysisController(this._repository);

  final status = AnalysisScreenStatus.starting.obs;
  final progressText = 'Starting…'.obs;
  final errorMessage = RxnString();
  final Rxn<AssessmentResult> result = Rxn<AssessmentResult>();

  Timer? _pollTimer;
  int? assessmentId;

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> start(int id) async {
    assessmentId = id;
    status.value = AnalysisScreenStatus.starting;
    errorMessage.value = null;

    try {
      await _repository.startAnalysis(id);
      status.value = AnalysisScreenStatus.polling;
      _beginPolling();
    } catch (e) {
      _handleFailure(e);
    }
  }

  void _beginPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    if (assessmentId == null) return;
    try {
      final result = await _repository.pollStatus(assessmentId!);
      if (result.progressStep != null) {
        progressText.value = result.progressStep!;
      }

      if (result.status == 'complete') {
        _pollTimer?.cancel();
        await _loadResult();
      } else if (result.status == 'failed') {
        _pollTimer?.cancel();
        status.value = AnalysisScreenStatus.failed;
      }
      // else: still 'analyzing' — keep polling.
    } catch (e) {
      _pollTimer?.cancel();
      _handleFailure(e);
    }
  }

  Future<void> _loadResult() async {
    try {
      result.value = await _repository.fetchResult(assessmentId!);
      debugPrint('Analysis result: ${result.value}');
      status.value = AnalysisScreenStatus.done;
      Get.offNamed(AppRoutes.results);
    } catch (e) {
      _handleFailure(e);
    }
  }

  /// Lets the user retry the whole analysis after a failure
  /// (e.g. transient Gemini/network error on the backend).
  Future<void> retry() async {
    if (assessmentId != null) {
      await start(assessmentId!);
    }
  }

  void _handleFailure(Object e) {
    if (e is AuthFailure) {
      Get.find<SessionState>().markLoggedOut();
      Get.offAllNamed(AppRoutes.login);
      return;
    }
    final failure = e is Failure ? e : const UnknownFailure();
    errorMessage.value = failure.message;
    status.value = AnalysisScreenStatus.error;
  }
}
