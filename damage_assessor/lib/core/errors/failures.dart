sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Check your connection and try again.']);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class OtpInvalidFailure extends AuthFailure {
  const OtpInvalidFailure() : super('Invalid code. Please try again.');
}

class OtpExpiredFailure extends AuthFailure {
  const OtpExpiredFailure() : super('Code expired. Request a new one.');
}

class TooManyAttemptsFailure extends AuthFailure {
  const TooManyAttemptsFailure() : super('Too many attempts. Please wait before retrying.');
}

class SubscriptionRequiredFailure extends Failure {
  const SubscriptionRequiredFailure() : super('Subscription required to start a new assessment.');
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end. Please try again.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unexpected error.']);
}
