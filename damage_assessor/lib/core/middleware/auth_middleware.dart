import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../storage/local_storage.dart';

/// Guards any route that requires a logged-in user.
/// Checks for a stored JWT only — does NOT validate it server-side here
/// (that happens on the first API call via the 401 handling in each
/// repository). This middleware is just the "do we even have a session"
/// gate to avoid flashing protected screens before redirecting.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    // GetMiddleware redirect must be synchronous, so the token presence
    // check is done via a cached value set at app startup (see main.dart),
    // not an async read here.
    final hasSession = Get.find<SessionState>().hasToken;
    if (!hasSession) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}

/// Simple in-memory session flag, hydrated once at startup from
/// LocalStorage, kept in sync on login/logout. Avoids async work
/// inside GetMiddleware.redirect, which must return synchronously.
class SessionState {
  bool hasToken = false;

  Future<void> hydrate() async {
    final token = await LocalStorage.instance.getToken();
    hasToken = token != null;
  }

  void markLoggedIn() => hasToken = true;

  Future<void> markLoggedOut() async {
    hasToken = false;
    await LocalStorage.instance.clearToken();
  }
}
