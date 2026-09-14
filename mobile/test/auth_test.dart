import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';
import 'package:groupnav_mobile/features/auth/models/auth_state.dart';
import 'package:groupnav_mobile/features/auth/models/pilot_profile.dart';
import 'package:groupnav_mobile/features/auth/providers/auth_provider.dart';
import 'package:groupnav_mobile/features/auth/services/cognito_auth_service.dart';

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
    test('Request OTP transitions state to otpPending', () async {
      final authService = CognitoAuthService(
        config: dummyConfig,
        storage: MemoryAuthStorage(),
      );
      final notifier = AuthNotifier(authService);

      notifier.setPhoneOrEmail('+15551234567');
      notifier.setCallsign('Viper');
      notifier.setVehicleClass('touring');
      notifier.setBeaconColor('#00C48C');

      await notifier.requestOtp();

      expect(notifier.state.status, equals(AuthStatus.otpPending));
      expect(notifier.state.session, isNotNull);
      expect(notifier.state.resendCountdown, greaterThan(0));

      // Verify OTP validation with 6-digit code
      final success = await notifier.verifyOtp('123456');
      expect(success, isTrue);
      expect(notifier.state.status, equals(AuthStatus.authenticated));
      expect(notifier.state.pilot?.callsign, equals('Viper'));
      expect(notifier.state.pilot?.vehicleClass, equals('touring'));
      expect(notifier.state.pilot?.beaconColor, equals('#00C48C'));

      // Sign out
      await notifier.signOut();
      expect(notifier.state.status, equals(AuthStatus.initial));
      expect(notifier.state.isAuthenticated, isFalse);
    });
  });
}
