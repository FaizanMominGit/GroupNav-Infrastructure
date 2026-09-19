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
  final String? passwordResetDestination;
  final bool isPasswordResetLoading;
  final String? passwordResetError;
  final bool passwordResetSuccess;

  const AuthState({
    this.status = AuthStatus.initial,
    this.pilot,
    this.session,
    this.errorMessage,
    this.resendCountdown = 0,
    this.awsCredentials,
    this.passwordResetDestination,
    this.isPasswordResetLoading = false,
    this.passwordResetError,
    this.passwordResetSuccess = false,
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
    String? passwordResetDestination,
    bool? isPasswordResetLoading,
    String? passwordResetError,
    bool? passwordResetSuccess,
  }) {
    return AuthState(
      status: status ?? this.status,
      pilot: pilot ?? this.pilot,
      session: session ?? this.session,
      errorMessage: errorMessage ?? this.errorMessage,
      resendCountdown: resendCountdown ?? this.resendCountdown,
      awsCredentials: awsCredentials ?? this.awsCredentials,
      passwordResetDestination: passwordResetDestination ?? this.passwordResetDestination,
      isPasswordResetLoading: isPasswordResetLoading ?? this.isPasswordResetLoading,
      passwordResetError: passwordResetError ?? this.passwordResetError,
      passwordResetSuccess: passwordResetSuccess ?? this.passwordResetSuccess,
    );
  }

  AuthState clearPasswordReset() {
    return AuthState(
      status: status,
      pilot: pilot,
      session: session,
      errorMessage: errorMessage,
      resendCountdown: resendCountdown,
      awsCredentials: awsCredentials,
      passwordResetDestination: null,
      isPasswordResetLoading: false,
      passwordResetError: null,
      passwordResetSuccess: false,
    );
  }
}
