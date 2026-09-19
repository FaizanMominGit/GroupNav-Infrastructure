import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';
import 'package:groupnav_mobile/core/services/aws_sigv4_signer.dart';
import 'package:groupnav_mobile/features/radar/models/convoy_route.dart';
import 'package:groupnav_mobile/features/radar/services/aws_location_route_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('RouteStop & ConvoyRoute Model Tests', () {
    test('RouteStop serialization and typeLabel', () {
      const origin = RouteStop(
        id: 'stop_1',
        name: 'Mumbai Point',
        latitude: 18.9220,
        longitude: 72.8347,
        type: RouteStopType.origin,
      );

      expect(origin.typeLabel, 'START');
      expect(origin.toLatLng, const LatLng(18.9220, 72.8347));

      final json = origin.toJson();
      expect(json['id'], 'stop_1');
      expect(json['type'], 'origin');

      final reconstructed = RouteStop.fromJson(json);
      expect(reconstructed.id, origin.id);
      expect(reconstructed.type, RouteStopType.origin);
      expect(reconstructed.latitude, 18.9220);
    });

    test('ConvoyRoute with stops and custom flag', () {
      final route = ConvoyRoute(
        id: 'custom_101',
        title: 'Lonavala Monsoon Ride',
        subtitle: '3 Stops • STAGGERED',
        distanceKm: 85.4,
        elevationGainMeters: 620,
        recommendedFormation: 'STAGGERED',
        waypoints: const [
          LatLng(18.9220, 72.8347),
          LatLng(18.7557, 73.4091),
          LatLng(18.7188, 73.3888),
        ],
        stops: const [
          RouteStop(
            id: 's1',
            name: 'Start',
            latitude: 18.9220,
            longitude: 72.8347,
            type: RouteStopType.origin,
          ),
          RouteStop(
            id: 's2',
            name: 'Lonavala Toll',
            latitude: 18.7557,
            longitude: 73.4091,
            type: RouteStopType.waypoint,
          ),
          RouteStop(
            id: 's3',
            name: 'Tiger Point',
            latitude: 18.7188,
            longitude: 73.3888,
            type: RouteStopType.destination,
          ),
        ],
        isCustom: true,
      );

      expect(route.isCustom, isTrue);
      expect(route.stops.length, 3);
      expect(route.intermediateStopsCount, 1);
      expect(route.startPoint, const LatLng(18.9220, 72.8347));
      expect(route.endPoint, const LatLng(18.7188, 73.3888));

      final json = route.toJson();
      expect(json['isCustom'], isTrue);
      expect((json['stops'] as List).length, 3);

      final decoded = ConvoyRoute.fromJson(json);
      expect(decoded.id, 'custom_101');
      expect(decoded.isCustom, isTrue);
      expect(decoded.stops.length, 3);
      expect(decoded.intermediateStopsCount, 1);
    });
  });

  group('AwsSigV4Signer REST Request Signing', () {
    test('signRestRequest generates valid SigV4 headers for Amazon Location Service', () {
      const signer = AwsSigV4Signer(
        region: 'ap-south-1',
        endpoint: 'a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com',
      );

      final fixedTime = DateTime.utc(2026, 9, 18, 12, 0, 0);
      final headers = signer.signRestRequest(
        method: 'POST',
        path: '/routes/v0/calculators/GroupNavRouteCalculator/calculate/route',
        service: 'geo',
        host: 'routes.geo.ap-south-1.amazonaws.com',
        body: '{"DeparturePosition":[72.8347,18.9220],"DestinationPosition":[73.3888,18.7188]}',
        accessKeyId: 'ASIAEXAMPLEKEY123',
        secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        sessionToken: 'SESSIONTOKEN123',
        requestTime: fixedTime,
      );

      expect(headers['Host'], 'routes.geo.ap-south-1.amazonaws.com');
      expect(headers['X-Amz-Date'], '20260918T120000Z');
      expect(headers['X-Amz-Security-Token'], 'SESSIONTOKEN123');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['Authorization'], startsWith('AWS4-HMAC-SHA256 Credential=ASIAEXAMPLEKEY123/20260918/ap-south-1/geo/aws4_request'));
      expect(headers['Authorization'], contains('SignedHeaders=content-type;host;x-amz-date;x-amz-security-token'));
    });
  });

  group('AwsLocationRouteService Tests', () {
    const config = ClientConfig(
      region: 'ap-south-1',
      cognito: CognitoConfig(userPoolId: '', userPoolClientId: '', identityPoolId: ''),
      location: LocationConfig(
        mapName: 'GroupNavMap',
        mapArn: '',
        geofenceCollectionName: '',
        geofenceCollectionArn: '',
        routeCalculatorName: 'GroupNavRouteCalculator',
        placeIndexName: 'GroupNavPlaceIndex',
      ),
      iot: IotConfig(endpoint: 'test.iot.ap-south-1.amazonaws.com'),
      network: NetworkConfig(vpcId: '', computeSecurityGroupId: '', dataSecurityGroupId: ''),
      data: DataConfig(redisEndpoint: '', auroraClusterEndpoint: ''),
      compute: ComputeConfig(lambdaArn: '', dlqUrl: '', telemetryTopicPattern: ''),
      cicd: CicdConfig(pipelineName: '', pipelineArn: '', gitHubConnectionArn: '', artifactBucketName: ''),
    );

    test('searchPlaces returns matching predefined landmarks', () async {
      final service = AwsLocationRouteService(config: config);
      final results = await service.searchPlaces(query: 'Tiger Point');

      expect(results, isNotEmpty);
      expect(results.first.label, contains('Tiger Point'));
      expect(results.first.latitude, closeTo(18.7188, 0.01));
    });

    test('calculateRoute generates valid route via geodesic fallback without credentials', () async {
      final service = AwsLocationRouteService(config: config);
      final stops = [
        const RouteStop(
          id: 's1',
          name: 'Mumbai',
          latitude: 18.9220,
          longitude: 72.8347,
          type: RouteStopType.origin,
        ),
        const RouteStop(
          id: 's2',
          name: 'Tiger Point',
          latitude: 18.7188,
          longitude: 73.3888,
          type: RouteStopType.destination,
        ),
      ];

      final route = await service.calculateRoute(
        title: 'Mumbai to Tiger Point',
        subtitle: 'Express Ghats',
        recommendedFormation: 'STAGGERED',
        stops: stops,
      );

      expect(route.title, 'Mumbai to Tiger Point');
      expect(route.isCustom, isTrue);
      expect(route.distanceKm, greaterThan(30.0));
      expect(route.waypoints.length, greaterThan(10));
      expect(route.startPoint, const LatLng(18.9220, 72.8347));
      expect(route.endPoint, const LatLng(18.7188, 73.3888));
    });
  });
}
