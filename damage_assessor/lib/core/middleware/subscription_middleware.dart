import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';

/// Guards the vehicle-info/capture entry point.
/// Per the spec: trial/subscription status must be checked live against
/// the backend at the moment "New assessment" is tapped — never from a
/// cached local flag.
///
/// STATUS: the real enforcement now lives server-side — POST /assessments
/// re-checks trial/subscription and returns 403 if blocked (see
/// assessmentController.js + AssessmentRepository.createAssessment,
/// which catches that 403 and redirects to the paywall). This client-side
/// middleware is intentionally left as a no-op: it would only ever
/// duplicate a check that's already enforced where it actually matters
/// (the server), and a client-side redirect here can't be trusted as
/// the real gate anyway since it's trivially bypassed by calling the
/// API directly.
class SubscriptionMiddleware extends GetMiddleware {
  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    return null;
  }
}
