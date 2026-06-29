import 'package:dio/dio.dart';
import '../storage/local_storage.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await LocalStorage.instance.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401 means the backend JWT is invalid/expired — caller repositories
    // should catch this and route back to login. Handled at repository
    // level rather than globally here, so each feature can decide
    // whether to show a message first (e.g. mid-capture vs on launch).
    handler.next(err);
  }
}
