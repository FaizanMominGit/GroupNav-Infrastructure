import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';

void main() {
  test('ClientConfig parses client-config.json accurately', () {
    final file = File('assets/config/client-config.json');
    expect(file.existsSync(), isTrue, reason: 'assets/config/client-config.json should exist');

    final jsonString = file.readAsStringSync();
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;

    final config = ClientConfig.fromJson(jsonMap);

    expect(config.region, equals('ap-south-1'));
    expect(config.cognito.userPoolId, equals('ap-south-1_JoK8Zlj1x'));
    expect(config.cognito.identityPoolId, equals('ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd'));
    expect(config.location.mapName, equals('GroupNavMap'));
    expect(config.iot.endpoint, contains('ats.iot.ap-south-1.amazonaws.com'));
    expect(config.compute.telemetryTopicPattern, equals('groupnav/{riderId}/telemetry'));
  });
}
