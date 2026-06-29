import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../auth/data/models/user_model.dart';

/// Fetches the current user's live profile + trial/subscription status.
/// Always hits the backend — per the spec, this must never be cached
/// locally, since subscription state can change at any moment
/// (expiry, payment success/failure, etc).
class DashboardRepository {
  Future<UserModel> fetchMe() async {
    try {
      final response = await apiClient.dio.get('/auth/me');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
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
}
