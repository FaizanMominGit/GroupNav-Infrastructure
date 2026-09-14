import 'pilot_profile.dart';

enum AuthStatus {
  initial,
  authenticating,
  otpPending,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final PilotProfile? pilot;
  final String? session;
  final String? errorMessage;
  final int resendCountdown;
  final Map<String, String>? awsCredentials;

  const AuthState({
    this.status = AuthStatus.initial,
    this.pilot,
    this.session,
    this.errorMessage,
    this.resendCountdown = 0,
    this.awsCredentials,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && pilot != null;
  bool get isOtpPending => status == AuthStatus.otpPending;
  bool get isLoading => status == AuthStatus.authenticating;

  AuthState copyWith({
    AuthStatus? status,
    PilotProfile? pilot,
    String? session,
    String? errorMessage,
    int? resendCountdown,
    Map<String, String>? awsCredentials,
  }) {
    return AuthState(
      status: status ?? this.status,
      pilot: pilot ?? this.pilot,
      session: session ?? this.session,
      errorMessage: errorMessage ?? this.errorMessage,
      resendCountdown: resendCountdown ?? this.resendCountdown,
      awsCredentials: awsCredentials ?? this.awsCredentials,
    );
  }
}
