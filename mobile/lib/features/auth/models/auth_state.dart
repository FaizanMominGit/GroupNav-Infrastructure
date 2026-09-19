import 'pilot_profile.dart';
import '../services/web3_wallet_service.dart';

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
  final bool canUseBiometrics;
  final bool isBiometricEnabled;
  final bool isBiometricLoading;
  final String biometricTypeLabel;
  final bool isSocialAuthLoading;
  final bool isWeb3Connecting;
  final Web3ConnectionResult? connectedWallet;

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
    this.canUseBiometrics = false,
    this.isBiometricEnabled = false,
    this.isBiometricLoading = false,
    this.biometricTypeLabel = 'Biometrics',
    this.isSocialAuthLoading = false,
    this.isWeb3Connecting = false,
    this.connectedWallet,
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
    bool? canUseBiometrics,
    bool? isBiometricEnabled,
    bool? isBiometricLoading,
    String? biometricTypeLabel,
    bool? isSocialAuthLoading,
    bool? isWeb3Connecting,
    Web3ConnectionResult? connectedWallet,
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
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isBiometricLoading: isBiometricLoading ?? this.isBiometricLoading,
      biometricTypeLabel: biometricTypeLabel ?? this.biometricTypeLabel,
      isSocialAuthLoading: isSocialAuthLoading ?? this.isSocialAuthLoading,
      isWeb3Connecting: isWeb3Connecting ?? this.isWeb3Connecting,
      connectedWallet: connectedWallet ?? this.connectedWallet,
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
      canUseBiometrics: canUseBiometrics,
      isBiometricEnabled: isBiometricEnabled,
      isBiometricLoading: isBiometricLoading,
      biometricTypeLabel: biometricTypeLabel,
      isSocialAuthLoading: isSocialAuthLoading,
      isWeb3Connecting: isWeb3Connecting,
      connectedWallet: connectedWallet,
    );
  }

  AuthState clearConnectedWallet() {
    return AuthState(
      status: status,
      pilot: pilot?.copyWith(walletAddress: '', navTokenBalance: 0.0),
      session: session,
      errorMessage: errorMessage,
      resendCountdown: resendCountdown,
      awsCredentials: awsCredentials,
      passwordResetDestination: passwordResetDestination,
      isPasswordResetLoading: isPasswordResetLoading,
      passwordResetError: passwordResetError,
      passwordResetSuccess: passwordResetSuccess,
      canUseBiometrics: canUseBiometrics,
      isBiometricEnabled: isBiometricEnabled,
      isBiometricLoading: isBiometricLoading,
      biometricTypeLabel: biometricTypeLabel,
      isSocialAuthLoading: isSocialAuthLoading,
      isWeb3Connecting: isWeb3Connecting,
      connectedWallet: null,
    );
  }
}
