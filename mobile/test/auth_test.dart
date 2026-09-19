import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';
import 'package:groupnav_mobile/features/auth/models/auth_state.dart';
import 'package:groupnav_mobile/features/auth/models/pilot_profile.dart';
import 'package:groupnav_mobile/features/auth/providers/auth_provider.dart';
import 'package:groupnav_mobile/features/auth/services/biometric_auth_service.dart';
import 'package:groupnav_mobile/features/auth/services/cognito_auth_service.dart';
import 'package:groupnav_mobile/features/auth/widgets/forgot_password_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyConfig = ClientConfig(
    region: 'ap-south-1',
    cognito: CognitoConfig(
      userPoolId: 'ap-south-1_test',
      userPoolClientId: 'client123',
      identityPoolId: 'ap-south-1:identity123',
    ),
    location: LocationConfig(
      mapName: 'GroupNavMap',
      mapArn: 'arn:aws:geo:ap-south-1:123:map/GroupNavMap',
      geofenceCollectionName: 'GroupNavGeofenceCollection',
      geofenceCollectionArn: 'arn:aws:geo:ap-south-1:123:geofence/collection',
    ),
    iot: IotConfig(endpoint: 'test.iot.ap-south-1.amazonaws.com'),
    network: NetworkConfig(vpcId: 'vpc-123', computeSecurityGroupId: 'sg-1', dataSecurityGroupId: 'sg-2'),
    data: DataConfig(redisEndpoint: 'localhost:6379', auroraClusterEndpoint: 'localhost:5432'),
    compute: ComputeConfig(lambdaArn: 'arn:lambda:123', dlqUrl: 'https://sqs', telemetryTopicPattern: 'groupnav/{riderId}/telemetry'),
    cicd: CicdConfig(pipelineName: 'pipe', pipelineArn: 'arn:pipe', gitHubConnectionArn: 'arn:conn', artifactBucketName: 'bucket'),
  );

  group('PilotProfile Unit Tests', () {
    test('Serializes to JSON and from JSON accurately', () {
      const profile = PilotProfile(
        phoneOrEmail: '+1 (555) 438-9201',
        callsign: '0xApex',
        vehicleClass: 'sportbike',
        beaconColor: '#0066FF',
        cognitoIdentityId: 'ap-south-1:identity123',
      );

      final jsonMap = profile.toJson();
      expect(jsonMap['callsign'], equals('0xApex'));
      expect(jsonMap['vehicleClass'], equals('sportbike'));

      final restored = PilotProfile.fromJson(jsonMap);
      expect(restored.callsign, equals(profile.callsign));
      expect(restored.phoneOrEmail, equals(profile.phoneOrEmail));
      expect(restored.cognitoIdentityId, equals(profile.cognitoIdentityId));
    });

    test('copyWith updates fields without mutating original', () {
      const profile = PilotProfile(
        phoneOrEmail: 'test@example.com',
        callsign: 'Ghost',
        vehicleClass: 'adventure',
        beaconColor: '#00D4FF',
      );

      final updated = profile.copyWith(callsign: 'Specter', vehicleClass: 'cruiser');
      expect(updated.callsign, equals('Specter'));
      expect(updated.vehicleClass, equals('cruiser'));
      expect(profile.callsign, equals('Ghost'));
    });
  });

  group('AuthState Unit Tests', () {
    test('Default AuthState is unauthenticated', () {
      const state = AuthState();
      expect(state.status, equals(AuthStatus.initial));
      expect(state.isAuthenticated, isFalse);
      expect(state.isOtpPending, isFalse);
      expect(state.isLoading, isFalse);
    });

    test('Authenticated state flags active pilot', () {
      const profile = PilotProfile(
        phoneOrEmail: 'pilot@example.com',
        callsign: '0xApex',
        vehicleClass: 'sportbike',
        beaconColor: '#0066FF',
      );
      const state = AuthState(
        status: AuthStatus.authenticated,
        pilot: profile,
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.pilot?.callsign, equals('0xApex'));
    });
  });

  group('AuthNotifier & CognitoAuthService Flow', () {
    test('Setters and mode toggling update AuthNotifier state cleanly', () async {
      final authService = CognitoAuthService(
        config: dummyConfig,
        storage: MemoryAuthStorage(),
      );
      final notifier = AuthNotifier(authService);

      notifier.setEmail('pilot@groupnav.io');
      notifier.setPassword('SecretPassword123');
      notifier.setCallsign('Viper');
      notifier.setVehicleClass('touring');
      notifier.setBeaconColor('#00C48C');

      expect(notifier.email, equals('pilot@groupnav.io'));
      expect(notifier.password, equals('SecretPassword123'));
      expect(notifier.callsign, equals('Viper'));
      expect(notifier.selectedVehicleClass, equals('touring'));
      expect(notifier.selectedBeaconColor, equals('#00C48C'));

      expect(notifier.isSignUpMode, isFalse);
      notifier.toggleSignUpMode();
      expect(notifier.isSignUpMode, isTrue);

      // Sign out resets state
      await notifier.signOut();
      expect(notifier.state.status, equals(AuthStatus.initial));
      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('sendPasswordResetCode validates email format before calling service', () async {
      final mockService = _MockCognitoAuthService();
      final notifier = AuthNotifier(mockService);

      // Empty email
      final result1 = await notifier.sendPasswordResetCode('');
      expect(result1, isNull);
      expect(mockService.forgotPasswordCalled, isFalse);
      expect(notifier.state.passwordResetError, contains('valid pilot email'));

      // Email missing @
      final result2 = await notifier.sendPasswordResetCode('invalid-email');
      expect(result2, isNull);
      expect(mockService.forgotPasswordCalled, isFalse);
    });

    test('sendPasswordResetCode initiates recovery and sets destination', () async {
      final mockService = _MockCognitoAuthService();
      final notifier = AuthNotifier(mockService);

      final result = await notifier.sendPasswordResetCode('pilot@groupnav.io');
      expect(result, isNotNull);
      expect(mockService.forgotPasswordCalled, isTrue);
      expect(mockService.lastRequestedEmail, equals('pilot@groupnav.io'));
      expect(notifier.state.passwordResetDestination, equals('p***@g***.io'));
      expect(notifier.state.passwordResetError, isNull);
      expect(notifier.state.resendCountdown, equals(60));
    });

    test('sendPasswordResetCode records error when Cognito service throws', () async {
      final mockService = _MockCognitoAuthService()..shouldFail = true;
      final notifier = AuthNotifier(mockService);

      final result = await notifier.sendPasswordResetCode('nonexistent@groupnav.io');
      expect(result, isNull);
      expect(notifier.state.passwordResetError, contains('User does not exist'));
      expect(notifier.state.isPasswordResetLoading, isFalse);
    });

    test('confirmPasswordReset validates code and password constraints', () async {
      final mockService = _MockCognitoAuthService();
      final notifier = AuthNotifier(mockService);

      // Code too short
      final shortCodeRes = await notifier.confirmPasswordReset(
        email: 'pilot@groupnav.io',
        code: '123',
        newPassword: 'NewPassword123!',
      );
      expect(shortCodeRes, isFalse);
      expect(mockService.confirmForgotPasswordCalled, isFalse);
      expect(notifier.state.passwordResetError, contains('6-digit'));

      // Password too short (< 8 chars)
      final shortPassRes = await notifier.confirmPasswordReset(
        email: 'pilot@groupnav.io',
        code: '123456',
        newPassword: 'short',
      );
      expect(shortPassRes, isFalse);
      expect(mockService.confirmForgotPasswordCalled, isFalse);
      expect(notifier.state.passwordResetError, contains('8 characters'));
    });

    test('confirmPasswordReset succeeds and updates password in state', () async {
      final mockService = _MockCognitoAuthService();
      final notifier = AuthNotifier(mockService);

      final success = await notifier.confirmPasswordReset(
        email: 'pilot@groupnav.io',
        code: '654321',
        newPassword: 'SecureNewPassword123!',
      );

      expect(success, isTrue);
      expect(mockService.confirmForgotPasswordCalled, isTrue);
      expect(mockService.lastSubmittedCode, equals('654321'));
      expect(mockService.lastSubmittedPassword, equals('SecureNewPassword123!'));
      expect(notifier.password, equals('SecureNewPassword123!'));
      expect(notifier.state.passwordResetSuccess, isTrue);
      expect(notifier.state.passwordResetError, isNull);
    });

    test('clearPasswordResetState resets transient password reset fields', () async {
      final mockService = _MockCognitoAuthService();
      final notifier = AuthNotifier(mockService);

      await notifier.sendPasswordResetCode('pilot@groupnav.io');
      expect(notifier.state.passwordResetDestination, isNotNull);

      notifier.clearPasswordResetState();
      expect(notifier.state.passwordResetDestination, isNull);
      expect(notifier.state.passwordResetError, isNull);
      expect(notifier.state.passwordResetSuccess, isFalse);
    });
  });

  group('ForgotPasswordDialog Widget Tests', () {
    testWidgets('Renders stage 0 and advances to stage 1 on code send', (tester) async {
      bool codeRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordDialog(
              initialEmail: 'pilot@groupnav.io',
              resendCountdown: 0,
              onRequestCode: (email) async {
                codeRequested = true;
                return true;
              },
              onConfirmReset: ({required email, required code, required newPassword}) async => true,
              onSuccess: (email, newPassword) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Reset Account Password'), findsOneWidget);
      expect(find.text('SEND CODE'), findsOneWidget);

      await tester.tap(find.text('SEND CODE'));
      await tester.pumpAndSettle();

      expect(codeRequested, isTrue);
      expect(find.text('Set New Password'), findsOneWidget);
      expect(find.text('RESET PASSWORD & SIGN IN'), findsOneWidget);
    });

    testWidgets('Renders stage 1 with destination and completes reset to stage 2', (tester) async {
      bool resetConfirmed = false;
      bool successInvoked = false;
      String? updatedEmail;
      String? updatedPass;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordDialog(
              initialEmail: 'pilot@groupnav.io',
              destination: 'p***@g***.io',
              resendCountdown: 0,
              onRequestCode: (email) async => true,
              onConfirmReset: ({required email, required code, required newPassword}) async {
                resetConfirmed = true;
                return true;
              },
              onSuccess: (email, newPassword) {
                successInvoked = true;
                updatedEmail = email;
                updatedPass = newPassword;
              },
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Set New Password'), findsOneWidget);
      expect(find.text('Code sent to: p***@g***.io'), findsOneWidget);

      // Enter 6-digit code, password, confirm password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '123456');
      await tester.enterText(textFields.at(1), 'SecurePass123!');
      await tester.enterText(textFields.at(2), 'SecurePass123!');
      await tester.pumpAndSettle();

      await tester.tap(find.text('RESET PASSWORD & SIGN IN'));
      await tester.pumpAndSettle();

      expect(resetConfirmed, isTrue);
      expect(find.text('Password Reset Complete'), findsOneWidget);
      expect(find.text('PROCEED TO SIGN IN'), findsOneWidget);

      await tester.tap(find.text('PROCEED TO SIGN IN'));
      await tester.pumpAndSettle();

      expect(successInvoked, isTrue);
      expect(updatedEmail, equals('pilot@groupnav.io'));
      expect(updatedPass, equals('SecurePass123!'));
    });
  });

  group('Biometric Unlock Unit & Flow Tests', () {
    test('MockBiometricService reports capabilities accurately', () async {
      final bio = MockBiometricService(mockTypes: ['Fingerprint', 'Face ID']);
      expect(await bio.canAuthenticate(), isTrue);
      expect(await bio.getAvailableBiometrics(), equals(['Fingerprint', 'Face ID']));
      expect(await bio.getPrimaryBiometricLabel(), equals('Fingerprint'));

      final authenticated = await bio.authenticate(localizedReason: 'Test');
      expect(authenticated, isTrue);
      expect(bio.authenticateCalled, isTrue);
    });

    test('checkBiometricAvailability sets canUseBiometrics when session exists and enabled', () async {
      final storage = MemoryAuthStorage();
      final authService = CognitoAuthService(config: dummyConfig, storage: storage);
      final bioService = MockBiometricService();
      final notifier = AuthNotifier(authService, biometricService: bioService);

      // Initially no session -> canUseBiometrics is false
      await notifier.checkBiometricAvailability();
      expect(notifier.state.canUseBiometrics, isFalse);

      // Seed valid session and enable biometrics
      await storage.write(
        key: 'groupnav_pilot_profile',
        value: '{"callsign":"Apex","phoneOrEmail":"pilot@groupnav.io","vehicleClass":"sportbike","beaconColor":"#0066FF","cognitoIdentityId":"id-123","cognitoSub":"sub-123"}',
      );
      await storage.write(
        key: 'groupnav_aws_credentials',
        value: '{"AccessKeyId":"AKIA...","SecretKey":"secret","SessionToken":"token"}',
      );
      await notifier.toggleBiometricLogin(true);

      expect(notifier.state.isBiometricEnabled, isTrue);
      expect(notifier.state.canUseBiometrics, isTrue);
      expect(notifier.state.biometricTypeLabel, equals('Fingerprint'));
    });

    test('unlockWithBiometrics succeeds and restores session', () async {
      final storage = MemoryAuthStorage();
      await storage.write(
        key: 'groupnav_pilot_profile',
        value: '{"callsign":"Apex","phoneOrEmail":"pilot@groupnav.io","vehicleClass":"sportbike","beaconColor":"#0066FF","cognitoIdentityId":"id-123","cognitoSub":"sub-123"}',
      );
      await storage.write(
        key: 'groupnav_aws_credentials',
        value: '{"AccessKeyId":"AKIA...","SecretKey":"secret","SessionToken":"token"}',
      );

      final authService = CognitoAuthService(config: dummyConfig, storage: storage);
      final bioService = MockBiometricService(shouldSucceed: true);
      final notifier = AuthNotifier(authService, biometricService: bioService);

      final success = await notifier.unlockWithBiometrics();
      expect(success, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.pilot?.callsign, equals('Apex'));
      expect(notifier.state.awsCredentials?['AccessKeyId'], equals('AKIA...'));
    });

    test('unlockWithBiometrics fails gracefully when user cancels or biometric fails', () async {
      final storage = MemoryAuthStorage();
      final authService = CognitoAuthService(config: dummyConfig, storage: storage);
      final bioService = MockBiometricService(shouldSucceed: false);
      final notifier = AuthNotifier(authService, biometricService: bioService);

      final success = await notifier.unlockWithBiometrics();
      expect(success, isFalse);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.errorMessage, contains('not completed'));
    });
  });
}

class _MockCognitoAuthService extends CognitoAuthService {
  bool forgotPasswordCalled = false;
  bool confirmForgotPasswordCalled = false;
  String? lastRequestedEmail;
  String? lastSubmittedCode;
  String? lastSubmittedPassword;
  bool shouldFail = false;
  String failMessage = 'AWS Cognito [UserNotFoundException]: User does not exist.';

  _MockCognitoAuthService()
      : super(
          config: const ClientConfig(
            region: 'ap-south-1',
            cognito: CognitoConfig(userPoolId: 'u', userPoolClientId: 'c', identityPoolId: 'i'),
            location: LocationConfig(mapName: 'm', mapArn: 'a', geofenceCollectionName: 'g', geofenceCollectionArn: 'ga'),
            iot: IotConfig(endpoint: 'e'),
            network: NetworkConfig(vpcId: 'v', computeSecurityGroupId: 'csg', dataSecurityGroupId: 'dsg'),
            data: DataConfig(redisEndpoint: 'r', auroraClusterEndpoint: 'a'),
            compute: ComputeConfig(lambdaArn: 'l', dlqUrl: 'd', telemetryTopicPattern: 't'),
            cicd: CicdConfig(pipelineName: 'p', pipelineArn: 'pa', gitHubConnectionArn: 'ga', artifactBucketName: 'b'),
          ),
          storage: MemoryAuthStorage(),
        );

  @override
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    forgotPasswordCalled = true;
    lastRequestedEmail = email;
    if (shouldFail) {
      throw Exception(failMessage);
    }
    return {
      'destination': 'p***@g***.io',
      'deliveryMedium': 'EMAIL',
      'attributeName': 'email',
    };
  }

  @override
  Future<bool> confirmForgotPassword({
    required String email,
    required String confirmationCode,
    required String newPassword,
  }) async {
    confirmForgotPasswordCalled = true;
    lastSubmittedCode = confirmationCode;
    lastSubmittedPassword = newPassword;
    if (shouldFail) {
      throw Exception(failMessage);
    }
    return true;
  }
}
