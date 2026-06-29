import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/errors/failures.dart';
import '../data/report_repository.dart';

enum ReportStatus { generating, ready, error }

class ReportController extends GetxController {
  final ReportRepository _repository;
  ReportController(this._repository);

  final status = ReportStatus.generating.obs;
  final errorMessage = RxnString();
  final localPdfPath = RxnString();

  Future<void> generate(int assessmentId) async {
    status.value = ReportStatus.generating;
    errorMessage.value = null;

    try {
      // Check for an already-downloaded local copy first — avoids
      // re-hitting the network (and re-downloading the same PDF) every
      // single time the user re-opens a report they've already viewed.
      final expectedPath = await _localPathFor(assessmentId);
      if (await File(expectedPath).exists()) {
        localPdfPath.value = expectedPath;
        status.value = ReportStatus.ready;
        return;
      }

      final pdfUrl = await _repository.generateReport(assessmentId);
      final localPath = await _downloadToLocal(pdfUrl, expectedPath);
      localPdfPath.value = localPath;
      status.value = ReportStatus.ready;
    } catch (e) {
      final failure = e is Failure ? e : const UnknownFailure();
      errorMessage.value = failure.message;
      status.value = ReportStatus.error;
    }
  }

  Future<String> _localPathFor(int assessmentId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/assessment_$assessmentId.pdf';
  }

  Future<String> _downloadToLocal(String pdfUrl, String filePath) async {
    final dio = Dio();
    await dio.download(pdfUrl, filePath);
    return filePath;
  }

  /// Forces a fresh download even if a local copy exists — useful if
  /// the cached local file is ever suspected corrupt, or for a manual
  /// "refresh" action later.
  Future<void> forceRedownload(int assessmentId) async {
    final expectedPath = await _localPathFor(assessmentId);
    final file = File(expectedPath);
    if (await file.exists()) {
      await file.delete();
    }
    await generate(assessmentId);
  }

  Future<void> retry(int assessmentId) => generate(assessmentId);
}
