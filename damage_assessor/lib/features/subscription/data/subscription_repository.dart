import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';

enum SubscriptionPlan { monthly, yearly }

extension SubscriptionPlanX on SubscriptionPlan {
  String get apiValue => this == SubscriptionPlan.monthly ? 'monthly' : 'yearly';
}

class SubscriptionRepository {
  /// Asks the backend to create a checkout session with the payment
  /// provider (Chargily) and returns a URL to open in the browser/webview.
  /// The backend itself talks to Chargily — the app never handles
  /// card details directly.
  Future<String> createCheckout(SubscriptionPlan plan) async {
    try {
      final response = await apiClient.dio.post(
        '/payments/checkout',
        data: {'plan': plan.apiValue},
      );
      return response.data['checkout_url'] as String;
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
