import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract class IBiometricService {
  Future<bool> canAuthenticate();
  Future<List<String>> getAvailableBiometrics();
  Future<String> getPrimaryBiometricLabel();
  Future<bool> authenticate({required String localizedReason});
}

class LocalBiometricService implements IBiometricService {
  final LocalAuthentication _auth;

  LocalBiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (e) {
      debugPrint('[BiometricService] canAuthenticate error: $e');
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableBiometrics() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.map((t) {
        switch (t) {
          case BiometricType.face:
            return 'Face ID';
          case BiometricType.fingerprint:
            return 'Fingerprint';
          case BiometricType.iris:
            return 'Iris';
          case BiometricType.strong:
            return 'Biometrics (Strong)';
          case BiometricType.weak:
            return 'Biometrics';
        }
      }).toList();
    } catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  @override
  Future<String> getPrimaryBiometricLabel() async {
    final available = await getAvailableBiometrics();
    if (available.contains('Face ID')) return 'Face ID';
    if (available.contains('Fingerprint')) return 'Fingerprint';
    if (available.isNotEmpty) return available.first;
    return 'Biometrics';
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}

class MockBiometricService implements IBiometricService {
  bool isSupported;
  bool shouldSucceed;
  List<String> mockTypes;
  bool authenticateCalled = false;

  MockBiometricService({
    this.isSupported = true,
    this.shouldSucceed = true,
    this.mockTypes = const ['Fingerprint', 'Face ID'],
  });

  @override
  Future<bool> canAuthenticate() async => isSupported;

  @override
  Future<List<String>> getAvailableBiometrics() async => mockTypes;

  @override
  Future<String> getPrimaryBiometricLabel() async =>
      mockTypes.isNotEmpty ? mockTypes.first : 'Biometrics';

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalled = true;
    return isSupported && shouldSucceed;
  }
}
