import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import 'models/result_model.dart';

class AnalysisRepository {
  /// Kicks off analysis — returns immediately (202), doesn't wait for completion.
  Future<void> startAnalysis(int assessmentId) async {
    try {
      await apiClient.dio.post('/assessments/$assessmentId/analyze');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Polled every ~2s while on the analyzing screen.
  Future<({String status, String? progressStep})> pollStatus(int assessmentId) async {
    try {
      final response = await apiClient.dio.get('/assessments/$assessmentId/status');
      return (
        status: response.data['status'] as String,
        progressStep: response.data['progress_step'] as String?,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<AssessmentResult> fetchResult(int assessmentId) async {
    try {
      final response = await apiClient.dio.get('/assessments/$assessmentId');
      return AssessmentResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Failure _mapError(DioException e) {
    if (e.response?.statusCode == 401) {
      return const AuthFailure('Session expired. Please log in again.');
    }
    if (e.response?.statusCode == 400) {
      return ServerFailure(e.response?.data['error'] as String? ?? 'Missing required photos.');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkFailure();
    }
    return const ServerFailure();
  }
}
