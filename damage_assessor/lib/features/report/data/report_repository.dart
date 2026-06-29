import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/env.dart';

class ReportRepository {
  Future<String> generateReport(int assessmentId) async {
    try {
      final response = await apiClient.dio.post(
        '/assessments/$assessmentId/report',
        options: Options(
          // The FastAPI pipeline can take 15–45s on a cold (uncached)
          // run — the global client default (30s) isn't enough here.
          // Only the first call per assessment is this slow; the
          // backend caches the PDF after that.
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 90),
        ),
      );
      final relativeUrl = response.data['pdf_url'] as String;
      return '${Env.apiBaseUrl}$relativeUrl';
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthFailure('Session expired. Please log in again.');
      }
      if (e.response?.statusCode == 400) {
        throw ServerFailure(e.response?.data['error'] as String? ?? 'Analysis not complete yet.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkFailure('Report generation is taking longer than expected. Please try again.');
      }
      throw const ServerFailure();
    }
  }
}