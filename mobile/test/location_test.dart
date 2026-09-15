import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/services/location_service.dart';

void main() {
  group('LocationService Unit Tests', () {
    test('Initializes with simulation mode and streams coordinates', () async {
      final service = LocationService(initialMode: LocationMode.simulation);
      expect(service.mode, equals(LocationMode.simulation));

      // Listen for the first coordinate event from simulation engine
      final firstPos = await service.positionStream.first;
      expect(firstPos.latitude, isNotNull);
      expect(firstPos.longitude, isNotNull);
      expect(firstPos.speedKmh, equals(78.0));
      expect(firstPos.headingDeg, equals(42.0));
      expect(firstPos.toLatLng.latitude, equals(firstPos.latitude));

      service.dispose();
    });

    test('PositionData formats readable string correctly', () {
      final pos = PositionData(
        latitude: 37.7749,
        longitude: -122.4194,
        speedKmh: 65.5,
        headingDeg: 90.0,
        timestamp: DateTime.now(),
      );
      expect(pos.toString(), contains('37.7749'));
      expect(pos.toString(), contains('-122.4194'));
      expect(pos.toString(), contains('65.5 km/h'));
      expect(pos.toString(), contains('90°'));
    });
  });
}
