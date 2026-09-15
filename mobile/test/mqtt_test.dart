import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';
import 'package:groupnav_mobile/core/services/aws_sigv4_signer.dart';
import 'package:groupnav_mobile/features/radar/services/iot_telemetry_service.dart';

void main() {
  const dummyConfig = ClientConfig(
    region: 'ap-south-1',
    cognito: CognitoConfig(userPoolId: 'u', userPoolClientId: 'c', identityPoolId: 'i'),
    location: LocationConfig(mapName: 'GroupNavMap', mapArn: 'a', geofenceCollectionName: 'g', geofenceCollectionArn: 'ga'),
    iot: IotConfig(endpoint: 'a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com'),
    network: NetworkConfig(vpcId: 'v', computeSecurityGroupId: 'csg', dataSecurityGroupId: 'dsg'),
    data: DataConfig(redisEndpoint: 'r', auroraClusterEndpoint: 'a'),
    compute: ComputeConfig(lambdaArn: 'l', dlqUrl: 'd', telemetryTopicPattern: 'groupnav/{riderId}/telemetry'),
    cicd: CicdConfig(pipelineName: 'p', pipelineArn: 'pa', gitHubConnectionArn: 'ga', artifactBucketName: 'b'),
  );

  group('AwsSigV4Signer Tests', () {
    test('Generates valid presigned WebSocket URL with SigV4 parameters', () {
      const signer = AwsSigV4Signer(
        region: 'ap-south-1',
        endpoint: 'a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com',
      );

      final fixedTime = DateTime.utc(2026, 9, 15, 12, 0, 0);
      final url = signer.generatePresignedWebSocketUrl(
        accessKeyId: 'ASIA_TEST_KEY',
        secretKey: 'TEST_SECRET_KEY',
        sessionToken: 'TEST_SESSION_TOKEN',
        requestTime: fixedTime,
      );

      expect(url, startsWith('wss://a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com/mqtt?'));
      expect(url, contains('X-Amz-Algorithm=AWS4-HMAC-SHA256'));
      expect(url, contains('X-Amz-Credential=ASIA_TEST_KEY%2F20260915%2Fap-south-1%2Fiotdevicegateway%2Faws4_request'));
      expect(url, contains('X-Amz-Date=20260915T120000Z'));
      expect(url, contains('X-Amz-SignedHeaders=host'));
      expect(url, contains('X-Amz-Security-Token=TEST_SESSION_TOKEN'));
      expect(url, contains('X-Amz-Signature='));
    });

    test('Omits session token if null or empty', () {
      const signer = AwsSigV4Signer(
        region: 'us-east-1',
        endpoint: 'test-endpoint.iot.us-east-1.amazonaws.com',
      );

      final url = signer.generatePresignedWebSocketUrl(
        accessKeyId: 'AKIA_STATIC_KEY',
        secretKey: 'STATIC_SECRET',
      );

      expect(url, isNot(contains('X-Amz-Security-Token')));
      expect(url, contains('X-Amz-Algorithm=AWS4-HMAC-SHA256'));
      expect(url, contains('X-Amz-Signature='));
    });
  });

  group('IotTelemetryService Alert Broadcast Tests', () {
    test('publishAlert emits to alertStream immediately', () async {
      final service = IotTelemetryService(config: dummyConfig);

      final completer = Completer<Map<String, dynamic>>();
      final sub = service.alertStream.listen((data) {
        completer.complete(data);
      });

      service.publishAlert(
        packId: '804',
        alertType: 'Regroup',
        callsign: 'Apex (Lead)',
        message: 'Regroup at checkpoint 3',
      );

      final received = await completer.future.timeout(const Duration(seconds: 2));
      expect(received['packId'], equals('804'));
      expect(received['alertType'], equals('Regroup'));
      expect(received['callsign'], equals('Apex (Lead)'));
      expect(received['message'], equals('Regroup at checkpoint 3'));
      expect(received['timestamp'], isNotNull);

      await sub.cancel();
      service.dispose();
    });
  });
}
