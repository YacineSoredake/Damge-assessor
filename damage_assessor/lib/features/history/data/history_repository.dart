import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import 'models/history_item_model.dart';

class HistoryRepository {
  Future<List<HistoryItem>> fetchPage({required int page, String? search, int limit = 20}) async {
    try {
      final response = await apiClient.dio.get('/assessments', queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return (response.data['assessments'] as List<dynamic>)
          .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
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

  Future<int> fetchTotalCount() async {
    try {
      final response = await apiClient.dio.get('/assessments', queryParameters: {'page': 1, 'limit': 1});
      return response.data['total'] as int? ?? 0;
    } on DioException {
      return 0; // non-critical stat — fail silently rather than block the dashboard
    }
  }
}