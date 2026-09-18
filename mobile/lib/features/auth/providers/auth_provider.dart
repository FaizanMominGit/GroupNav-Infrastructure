import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/client_config.dart';
import '../models/auth_state.dart';
import '../models/pilot_profile.dart';
import '../services/cognito_auth_service.dart';

final clientConfigProvider = Provider<ClientConfig>((ref) {
  throw UnimplementedError('clientConfigProvider must be initialized in ProviderScope overrides');
});

final cognitoAuthServiceProvider = Provider<CognitoAuthService>((ref) {
  final config = ref.watch(clientConfigProvider);
  return CognitoAuthService(config: config);
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(cognitoAuthServiceProvider);
  return AuthNotifier(authService);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final CognitoAuthService _authService;
  Timer? _countdownTimer;

  String _email = '';
  String _password = '';
  String _callsign = 'Apex';
  String _selectedVehicleClass = 'sportbike';
  String _selectedBeaconColor = '#0066FF';
  bool _isSignUpMode = false;

  AuthNotifier(this._authService) : super(const AuthState()) {
    checkSavedSession();
  }

  String get email => _email;
  String get password => _password;
  String get callsign => _callsign;
  String get selectedVehicleClass => _selectedVehicleClass;
  String get selectedBeaconColor => _selectedBeaconColor;
  bool get isSignUpMode => _isSignUpMode;

  void setEmail(String value) => _email = value.trim();
  void setPassword(String value) => _password = value;
  void setCallsign(String value) => _callsign = value.trim();
  void toggleSignUpMode() {
    _isSignUpMode = !_isSignUpMode;
    state = state.copyWith(errorMessage: null);
  }

  void setVehicleClass(String value) {
    _selectedVehicleClass = value;
    if (state.pilot != null) {
      state = state.copyWith(
        pilot: state.pilot!.copyWith(vehicleClass: value),
      );
    }
  }

  void setBeaconColor(String value) {
    _selectedBeaconColor = value;
    if (state.pilot != null) {
      state = state.copyWith(
        pilot: state.pilot!.copyWith(beaconColor: value),
      );
    }
  }

  /// Check if an authenticated pilot session already exists in device secure storage
  Future<void> checkSavedSession() async {
    try {
      final savedPilot = await _authService.restoreSession();
      if (savedPilot != null) {
        final creds = await _authService.getCachedCredentials();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          pilot: savedPilot,
          awsCredentials: creds,
        );
      }
    } catch (_) {}
  }

  /// Sign up with AWS Cognito User Pool
  Future<bool> signUp({
    required String email,
    required String password,
    required String callsign,
  }) async {
    _email = email.trim();
    _password = password;
    _callsign = callsign.trim();

    if (_email.isEmpty || _password.isEmpty || _callsign.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter email, password, and callsign.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final result = await _authService.signUp(
        email: _email,
        password: _password,
        callsign: _callsign,
      );

      final isConfirmed = result['userConfirmed'] as bool? ?? false;
      if (isConfirmed) {
        // Automatically sign in if auto-confirmed
        return await signIn(email: _email, password: _password);
      } else {
        _startResendTimer(60);
        state = state.copyWith(
          status: AuthStatus.otpPending,
          errorMessage: null,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Confirm sign up using the 6-digit confirmation code from email
  Future<bool> confirmSignUp(String code) async {
    if (code.trim().length != 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter the 6-digit code sent to your email.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      await _authService.confirmSignUp(
        email: _email,
        confirmationCode: code.trim(),
      );

      // Successfully confirmed, proceed to sign in with credentials
      return await signIn(email: _email, password: _password);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.otpPending,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Sign in with AWS Cognito User Pool and acquire real AWS temporary credentials
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _email = email.trim();
    _password = password;

    if (_email.isEmpty || _password.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter email and password.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final result = await _authService.signIn(
        email: _email,
        password: _password,
        callsign: _callsign,
        vehicleClass: _selectedVehicleClass,
        beaconColor: _selectedBeaconColor,
      );

      _countdownTimer?.cancel();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        pilot: result['pilot'] as PilotProfile?,
        awsCredentials: result['awsCredentials'] as Map<String, String>?,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('UserNotConfirmedException')) {
        // Needs confirmation
        _startResendTimer(60);
        state = state.copyWith(
          status: AuthStatus.otpPending,
          errorMessage: 'Account not yet confirmed. Please enter the verification code sent to your email.',
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: msg,
        );
      }
      return false;
    }
  }

  /// Resend confirmation code
  Future<void> resendConfirmationCode() async {
    if (_email.isEmpty) return;
    try {
      await _authService.resendConfirmationCode(email: _email);
      _startResendTimer(60);
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void cancelOtp() {
    _countdownTimer?.cancel();
    state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
  }

  Future<void> signOut() async {
    _countdownTimer?.cancel();
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.initial);
  }

  void _startResendTimer(int seconds) {
    _countdownTimer?.cancel();
    state = state.copyWith(resendCountdown: seconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendCountdown <= 1) {
        timer.cancel();
        state = state.copyWith(resendCountdown: 0);
      } else {
        state = state.copyWith(resendCountdown: state.resendCountdown - 1);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
