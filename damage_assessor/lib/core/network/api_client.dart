import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../config/env.dart';
import 'auth_interceptor.dart';

/// Single shared Dio instance, injected via Get so every repository
/// uses the same base config/interceptors instead of constructing
/// its own client.
class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(AuthInterceptor());
    if (!Env.isProd) {
      dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }
  }
}

/// Call once in main() before runApp: Get.put(ApiClient(), permanent: true);
ApiClient get apiClient => Get.find<ApiClient>();
