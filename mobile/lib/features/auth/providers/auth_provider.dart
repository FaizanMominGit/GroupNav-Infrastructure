import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/client_config.dart';
import '../models/auth_state.dart';
import '../models/pilot_profile.dart';
import '../services/biometric_auth_service.dart';
import '../services/cognito_auth_service.dart';
import '../services/social_auth_service.dart';
import '../services/web3_wallet_service.dart';

final clientConfigProvider = Provider<ClientConfig>((ref) {
  throw UnimplementedError('clientConfigProvider must be initialized in ProviderScope overrides');
});

final cognitoAuthServiceProvider = Provider<CognitoAuthService>((ref) {
  final config = ref.watch(clientConfigProvider);
  return CognitoAuthService(config: config);
});

final biometricServiceProvider = Provider<IBiometricService>((ref) {
  return LocalBiometricService();
});

final socialAuthServiceProvider = Provider<ISocialAuthService>((ref) {
  return LocalSocialAuthService();
});

final web3WalletServiceProvider = Provider<IWeb3WalletService>((ref) {
  return ProductionWeb3WalletService();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(cognitoAuthServiceProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  final socialAuthService = ref.watch(socialAuthServiceProvider);
  final web3WalletService = ref.watch(web3WalletServiceProvider);
  return AuthNotifier(
    authService,
    biometricService: biometricService,
    socialAuthService: socialAuthService,
    web3WalletService: web3WalletService,
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final CognitoAuthService _authService;
  final IBiometricService _biometricService;
  final ISocialAuthService _socialAuthService;
  final IWeb3WalletService _web3WalletService;
  Timer? _countdownTimer;

  String _email = '';
  String _password = '';
  String _callsign = '';
  String _selectedVehicleClass = 'sportbike';
  String _selectedBeaconColor = '#0066FF';
  bool _isSignUpMode = false;

  AuthNotifier(
    this._authService, {
    IBiometricService? biometricService,
    ISocialAuthService? socialAuthService,
    IWeb3WalletService? web3WalletService,
  })  : _biometricService = biometricService ?? LocalBiometricService(),
        _socialAuthService = socialAuthService ?? LocalSocialAuthService(),
        _web3WalletService = web3WalletService ?? ProductionWeb3WalletService(),
        super(const AuthState()) {
    checkSavedSession();
    checkBiometricAvailability();
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

  Future<void> updateCallsign(String newCallsign) async {
    final clean = newCallsign.trim();
    if (clean.isEmpty) return;
    _callsign = clean;
    if (state.pilot != null) {
      state = state.copyWith(
        pilot: state.pilot!.copyWith(callsign: clean),
      );
    }
    await _authService.updateCallsign(clean);
  }

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
        _callsign = savedPilot.callsign;
        final creds = await _authService.getCachedCredentials();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          pilot: savedPilot,
          awsCredentials: creds,
        );
      }
    } catch (_) {}
  }

  /// Check whether biometric authentication can be offered on device
  Future<void> checkBiometricAvailability() async {
    try {
      final canAuth = await _biometricService.canAuthenticate();
      final label = await _biometricService.getPrimaryBiometricLabel();
      final hasSavedSession = await _authService.hasSavedSession();
      final isEnabled = await _authService.isBiometricEnabled();

      state = state.copyWith(
        canUseBiometrics: canAuth && hasSavedSession && isEnabled,
        isBiometricEnabled: isEnabled,
        biometricTypeLabel: label,
      );
    } catch (_) {}
  }

  /// Authenticate using device biometrics and restore the authenticated Cognito session
  Future<bool> unlockWithBiometrics() async {
    state = state.copyWith(isBiometricLoading: true, errorMessage: null);

    try {
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate with ${state.biometricTypeLabel} to unlock your GroupNav convoy session',
      );

      if (!authenticated) {
        state = state.copyWith(
          isBiometricLoading: false,
          errorMessage: 'Biometric authentication was not completed.',
        );
        return false;
      }

      final savedPilot = await _authService.restoreSession();
      if (savedPilot != null) {
        final creds = await _authService.getCachedCredentials();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          pilot: savedPilot,
          awsCredentials: creds,
          isBiometricLoading: false,
          errorMessage: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isBiometricLoading: false,
          errorMessage: 'No stored credentials found. Please sign in with password.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isBiometricLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Toggle biometric unlock preference and update state
  Future<void> toggleBiometricLogin(bool enabled) async {
    await _authService.setBiometricEnabled(enabled);
    await checkBiometricAvailability();
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
        callsign: _callsign.trim().isNotEmpty ? _callsign.trim() : null,
        vehicleClass: _selectedVehicleClass,
        beaconColor: _selectedBeaconColor,
      );

      _countdownTimer?.cancel();

      final authenticatedPilot = result['pilot'] as PilotProfile?;
      if (authenticatedPilot != null) {
        _callsign = authenticatedPilot.callsign;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        pilot: authenticatedPilot,
        awsCredentials: result['awsCredentials'] as Map<String, String>?,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('UserNotConfirmedException')) {
        _startResendTimer(60);
        state = state.copyWith(
          status: AuthStatus.otpPending,
          errorMessage: 'Account not yet confirmed. Please enter the 6-digit code.',
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

  /// Sign in with Google (OAuth2 / Social Federation)
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isSocialAuthLoading: true, errorMessage: null);
    try {
      final result = await _socialAuthService.signInWithGoogle();
      if (result == null) {
        state = state.copyWith(isSocialAuthLoading: false);
        return false;
      }

      final pilot = PilotProfile(
        phoneOrEmail: result.email,
        callsign: result.displayName.isNotEmpty ? result.displayName : 'GooglePilot',
        vehicleClass: _selectedVehicleClass,
        beaconColor: _selectedBeaconColor,
        authProviderType: 'google',
      );

      _countdownTimer?.cancel();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        pilot: pilot,
        isSocialAuthLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSocialAuthLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Sign in with Apple (Sign in with Apple ID)
  Future<bool> signInWithApple() async {
    state = state.copyWith(isSocialAuthLoading: true, errorMessage: null);
    try {
      final result = await _socialAuthService.signInWithApple();
      if (result == null) {
        state = state.copyWith(isSocialAuthLoading: false);
        return false;
      }

      final pilot = PilotProfile(
        phoneOrEmail: result.email,
        callsign: result.displayName.isNotEmpty ? result.displayName : 'ApplePilot',
        vehicleClass: _selectedVehicleClass,
        beaconColor: _selectedBeaconColor,
        authProviderType: 'apple',
      );

      _countdownTimer?.cancel();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        pilot: pilot,
        isSocialAuthLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSocialAuthLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Sign in directly via Web3 Wallet (MetaMask, Phantom, WalletConnect) with SIWE
  Future<bool> signInWithWeb3(
    Web3WalletType walletType, {
    Web3Chain chain = Web3Chain.polygon,
  }) async {
    state = state.copyWith(isWeb3Connecting: true, errorMessage: null);
    try {
      final result = await _web3WalletService.connectWallet(walletType, chain: chain);

      final pilot = PilotProfile(
        phoneOrEmail: '${result.walletAddress}@depin.groupnav.io',
        callsign: '0x${result.truncatedAddress.replaceAll("...", "").toLowerCase().substring(0, 4)}',
        vehicleClass: _selectedVehicleClass,
        beaconColor: _selectedBeaconColor,
        walletAddress: result.walletAddress,
        authProviderType: 'web3',
        navTokenBalance: result.balanceNAV,
      );

      _countdownTimer?.cancel();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        pilot: pilot,
        connectedWallet: result,
        isWeb3Connecting: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isWeb3Connecting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Link a Web3 Wallet to an active pilot account for DePIN proof-of-ride telemetry rewards
  Future<bool> linkWeb3Wallet(
    Web3WalletType walletType, {
    Web3Chain chain = Web3Chain.polygon,
  }) async {
    state = state.copyWith(isWeb3Connecting: true, errorMessage: null);
    try {
      final result = await _web3WalletService.connectWallet(walletType, chain: chain);
      final currentPilot = state.pilot;
      final updatedPilot = currentPilot?.copyWith(
        walletAddress: result.walletAddress,
        navTokenBalance: result.balanceNAV,
      );

      state = state.copyWith(
        connectedWallet: result,
        pilot: updatedPilot,
        isWeb3Connecting: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isWeb3Connecting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Disconnect the linked Web3 wallet
  Future<void> disconnectWeb3Wallet() async {
    await _web3WalletService.disconnectWallet();
    state = state.clearConnectedWallet();
  }

  /// Quick guest / offline ride entry
  void skipAuth() {
    _countdownTimer?.cancel();
    final guestPilot = PilotProfile(
      phoneOrEmail: 'guest_rider@groupnav.local',
      callsign: _callsign.isNotEmpty ? _callsign : 'GhostRider',
      vehicleClass: _selectedVehicleClass,
      beaconColor: _selectedBeaconColor,
      authProviderType: 'guest',
    );
    state = state.copyWith(
      status: AuthStatus.authenticated,
      pilot: guestPilot,
      errorMessage: null,
    );
  }

  /// Resend confirmation code to user's email
  Future<bool> resendConfirmationCode() async {
    if (_email.isEmpty) return false;

    state = state.copyWith(errorMessage: null);

    try {
      await _authService.resendConfirmationCode(email: _email);
      _startResendTimer(60);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Request a password reset code for a forgotten password
  Future<String?> sendPasswordResetCode(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = state.copyWith(
        passwordResetError: 'Please enter a valid pilot email address.',
        isPasswordResetLoading: false,
      );
      return null;
    }

    state = state.copyWith(
      isPasswordResetLoading: true,
      passwordResetError: null,
      passwordResetSuccess: false,
    );

    try {
      final result = await _authService.forgotPassword(email: trimmedEmail);
      final destination = result['destination'] as String? ?? trimmedEmail;
      _email = trimmedEmail;
      _startResendTimer(60);

      state = state.copyWith(
        isPasswordResetLoading: false,
        passwordResetDestination: destination,
        passwordResetError: null,
      );
      return destination;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isPasswordResetLoading: false,
        passwordResetError: msg,
      );
      return null;
    }
  }

  /// Submit the confirmation code and new password to AWS Cognito
  Future<bool> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final trimmedCode = code.trim();
    if (trimmedCode.length != 6) {
      state = state.copyWith(
        passwordResetError: 'Please enter the 6-digit confirmation code.',
        isPasswordResetLoading: false,
      );
      return false;
    }

    if (newPassword.length < 8) {
      state = state.copyWith(
        passwordResetError: 'Password must be at least 8 characters long.',
        isPasswordResetLoading: false,
      );
      return false;
    }

    state = state.copyWith(
      isPasswordResetLoading: true,
      passwordResetError: null,
    );

    try {
      await _authService.confirmForgotPassword(
        email: email.trim(),
        confirmationCode: trimmedCode,
        newPassword: newPassword,
      );

      _password = newPassword;
      _countdownTimer?.cancel();

      state = state.copyWith(
        isPasswordResetLoading: false,
        passwordResetSuccess: true,
        passwordResetError: null,
        resendCountdown: 0,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isPasswordResetLoading: false,
        passwordResetError: msg,
      );
      return false;
    }
  }

  /// Clear password reset transient state
  void clearPasswordResetState() {
    state = state.clearPasswordReset();
  }

  void cancelOtp() {
    _countdownTimer?.cancel();
    state = state.copyWith(
      status: AuthStatus.initial,
      resendCountdown: 0,
      errorMessage: null,
    );
  }

  Future<void> signOut() async {
    _countdownTimer?.cancel();
    _email = '';
    _password = '';
    _callsign = '';
    await _authService.signOut();
    await _socialAuthService.signOut();
    await _web3WalletService.disconnectWallet();
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
