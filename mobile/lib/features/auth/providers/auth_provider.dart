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

  String _phoneOrEmail = '+1 (555) 438-9201';
  String _callsign = '0xApex';
  String _selectedVehicleClass = 'sportbike';
  String _selectedBeaconColor = '#0066FF';

  AuthNotifier(this._authService) : super(const AuthState()) {
    checkSavedSession();
  }

  String get phoneOrEmail => _phoneOrEmail;
  String get callsign => _callsign;
  String get selectedVehicleClass => _selectedVehicleClass;
  String get selectedBeaconColor => _selectedBeaconColor;

  void setPhoneOrEmail(String value) => _phoneOrEmail = value;
  void setCallsign(String value) => _callsign = value;

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
    final savedPilot = await _authService.restoreSession();
    if (savedPilot != null) {
      final creds = await _authService.getCachedCredentials();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        pilot: savedPilot,
        awsCredentials: creds,
      );
    }
  }

  /// Request OTP from Cognito
  Future<void> requestOtp() async {
    if (_phoneOrEmail.trim().isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter pilot phone or email.',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final result = await _authService.initiateAuth(
        phoneOrEmail: _phoneOrEmail,
        callsign: _callsign,
      );

      _startResendTimer(45);

      state = state.copyWith(
        status: AuthStatus.otpPending,
        session: result['session'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Verify entered 6-digit OTP
  Future<bool> verifyOtp(String code) async {
    if (code.length != 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter a valid 6-digit code.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final result = await _authService.verifyOtp(
        phoneOrEmail: _phoneOrEmail,
        otpCode: code,
        session: state.session ?? '0x82A1B9E3C1',
        callsign: _callsign,
        vehicleClass: _selectedVehicleClass,
        beaconColor: _selectedBeaconColor,
      );

      _countdownTimer?.cancel();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        pilot: result['pilot'] as PilotProfile?,
        awsCredentials: result['awsCredentials'] as Map<String, String>?,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.otpPending,
        errorMessage: 'Invalid OTP. Please try again.',
      );
      return false;
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
