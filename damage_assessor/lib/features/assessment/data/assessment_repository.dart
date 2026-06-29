import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import 'models/photo_model.dart';

class AssessmentRepository {
  /// Creates the assessment row server-side. The backend independently
  /// re-checks trial/subscription here (not just trusting the dashboard's
  /// earlier check) — if it returns a 403, the trial/subscription must
  /// have changed between the dashboard check and now (rare, but the
  /// spec requires handling it rather than assuming it can't happen).
  Future<int> createAssessment({
    required String plateNumber,
    String? vehicleMakeModel,
    String? clientReference,
    String? notes,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/assessments',
        data: {
          'plate_number': plateNumber,
          if (vehicleMakeModel != null) 'vehicle_make_model': vehicleMakeModel,
          if (clientReference != null) 'client_reference': clientReference,
          if (notes != null) 'notes': notes,
        },
      );
      return response.data['assessment_id'] as int;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw const SubscriptionRequiredFailure();
      }
      if (e.response?.statusCode == 401) {
        throw const AuthFailure('Session expired. Please log in again.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkFailure();
      }
      throw const ServerFailure();
    }
  }

  /// Uploads a single photo for the given assessment. Throws on failure
  /// so the controller can mark that specific photo as failed and offer
  /// a retry, rather than silently losing it (per the spec's edge case
  /// on poor connectivity in the field).
  Future<int> uploadPhoto({
    required int assessmentId,
    required CapturedPhoto photo,
  }) async {
    try {
      final formData = FormData.fromMap({
        'type': photo.type.apiValue,
        'photo': await MultipartFile.fromFile(photo.localPath),
      });
      final response = await apiClient.dio.post(
        '/assessments/$assessmentId/photos',
        data: formData,
      );
      return response.data['photo_id'] as int;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout) {
        throw const NetworkFailure('Upload failed. Check your connection and retry.');
      }
      throw const ServerFailure('Could not upload photo. Please retry.');
    }
  }
}
