import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/features/settings/models/rider_settings.dart';
import 'package:groupnav_mobile/features/settings/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GpsRate Enum Tests', () {
    test('Labels and shortLabels map correctly', () {
      expect(GpsRate.oneHz.label, '1 Hz (Battery Saver)');
      expect(GpsRate.fiveHz.label, '5 Hz (Balanced)');
      expect(GpsRate.tenHz.label, '10 Hz (Pro Convoy)');

      expect(GpsRate.oneHz.shortLabel, '1 Hz');
      expect(GpsRate.fiveHz.shortLabel, '5 Hz');
      expect(GpsRate.tenHz.shortLabel, '10 Hz');
    });

    test('Interval durations match telemetry frequency specs', () {
      expect(GpsRate.oneHz.intervalDuration, const Duration(milliseconds: 1000));
      expect(GpsRate.fiveHz.intervalDuration, const Duration(milliseconds: 200));
      expect(GpsRate.tenHz.intervalDuration, const Duration(milliseconds: 100));
    });

    test('Distance filters clamp to optimal tracking precision', () {
      expect(GpsRate.oneHz.distanceFilterMeters, 5.0);
      expect(GpsRate.fiveHz.distanceFilterMeters, 2.0);
      expect(GpsRate.tenHz.distanceFilterMeters, 0.5);
    });
  });

  group('UnitSystem Enum Tests', () {
    test('Metric formats correctly', () {
      expect(UnitSystem.metric.speedUnit, 'km/h');
      expect(UnitSystem.metric.distanceUnit, 'meters');
      expect(UnitSystem.metric.longDistanceUnit, 'km');
      expect(UnitSystem.metric.label, 'Metric (km/h)');
    });

    test('Imperial formats correctly', () {
      expect(UnitSystem.imperial.speedUnit, 'mph');
      expect(UnitSystem.imperial.distanceUnit, 'feet');
      expect(UnitSystem.imperial.longDistanceUnit, 'mi');
      expect(UnitSystem.imperial.label, 'Imperial (mph)');
    });
  });

  group('MapThemeMode Enum Tests', () {
    test('Theme labels map to visual styles', () {
      expect(MapThemeMode.day.label, 'Day');
      expect(MapThemeMode.night.label, 'Night');
      expect(MapThemeMode.system.label, 'Auto');
    });
  });

  group('RiderSettings Model Tests', () {
    test('Initializes with default Convoy Telemetry values', () {
      const settings = RiderSettings();
      expect(settings.gpsRate, GpsRate.fiveHz);
      expect(settings.backgroundBroadcast, true);
      expect(settings.highPrecisionGeofenceAlert, true);
      expect(settings.unitSystem, UnitSystem.metric);
      expect(settings.mapThemeMode, MapThemeMode.system);
      expect(settings.cohesionPingAudio, true);
      expect(settings.stakedBalanceNav, 142.8);
      expect(settings.navRewardRate, 4.2);
      expect(settings.walletAddress.isNotEmpty, true);
    });

    test('copyWith properly updates selected fields without mutation', () {
      const original = RiderSettings();
      final updated = original.copyWith(
        gpsRate: GpsRate.tenHz,
        backgroundBroadcast: false,
        unitSystem: UnitSystem.imperial,
        mapThemeMode: MapThemeMode.night,
        cohesionPingAudio: false,
        stakedBalanceNav: 200.0,
      );

      expect(updated.gpsRate, GpsRate.tenHz);
      expect(updated.backgroundBroadcast, false);
      expect(updated.unitSystem, UnitSystem.imperial);
      expect(updated.mapThemeMode, MapThemeMode.night);
      expect(updated.cohesionPingAudio, false);
      expect(updated.stakedBalanceNav, 200.0);
      expect(updated.navRewardRate, original.navRewardRate);
      expect(updated.walletAddress, original.walletAddress);
    });
  });

  group('SettingsNotifier State Management Tests', () {
    test('setGpsRate changes GPS sampling frequency', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.gpsRate, GpsRate.fiveHz);

      notifier.setGpsRate(GpsRate.oneHz);
      expect(notifier.state.gpsRate, GpsRate.oneHz);

      notifier.setGpsRate(GpsRate.tenHz);
      expect(notifier.state.gpsRate, GpsRate.tenHz);
    });

    test('toggleBackgroundBroadcast toggles background transmission', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.backgroundBroadcast, true);

      notifier.toggleBackgroundBroadcast(false);
      expect(notifier.state.backgroundBroadcast, false);

      notifier.toggleBackgroundBroadcast(true);
      expect(notifier.state.backgroundBroadcast, true);
    });

    test('toggleHighPrecisionAlert toggles lane departure alerts', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.highPrecisionGeofenceAlert, true);

      notifier.toggleHighPrecisionAlert(false);
      expect(notifier.state.highPrecisionGeofenceAlert, false);

      notifier.toggleHighPrecisionAlert(true);
      expect(notifier.state.highPrecisionGeofenceAlert, true);
    });

    test('setUnitSystem updates measurement system', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.unitSystem, UnitSystem.metric);

      notifier.setUnitSystem(UnitSystem.imperial);
      expect(notifier.state.unitSystem, UnitSystem.imperial);
    });

    test('setMapTheme updates theme preference', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.mapThemeMode, MapThemeMode.system);

      notifier.setMapTheme(MapThemeMode.day);
      expect(notifier.state.mapThemeMode, MapThemeMode.day);

      notifier.setMapTheme(MapThemeMode.night);
      expect(notifier.state.mapThemeMode, MapThemeMode.night);
    });

    test('toggleCohesionPingAudio toggles spatial audio chime', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.cohesionPingAudio, true);

      notifier.toggleCohesionPingAudio(false);
      expect(notifier.state.cohesionPingAudio, false);
    });

    test('Profile & Identity mutations update state correctly', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.callsign, 'Pilot');
      expect(notifier.state.vehicle, 'Motorcycle');
      expect(notifier.state.emergencyContact, '');

      notifier.setCallsign('ViperOne');
      notifier.setVehicle('BMW S1000RR');
      notifier.setEmergencyContact('Marcus (+1 555-0200)');

      expect(notifier.state.callsign, 'ViperOne');
      expect(notifier.state.vehicle, 'BMW S1000RR');
      expect(notifier.state.emergencyContact, 'Marcus (+1 555-0200)');
    });

    test('Ride & Convoy Alert toggles update state correctly', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.geofenceDepartureWarning, true);
      expect(notifier.state.speedAlert, true);
      expect(notifier.state.voiceAudioCues, true);

      notifier.toggleGeofenceDepartureWarning(false);
      notifier.toggleSpeedAlert(false);
      notifier.toggleVoiceAudioCues(false);

      expect(notifier.state.geofenceDepartureWarning, false);
      expect(notifier.state.speedAlert, false);
      expect(notifier.state.voiceAudioCues, false);
    });

    test('Location & Privacy toggles update state correctly', () {
      final notifier = SettingsNotifier();
      expect(notifier.state.shareRealTimeLocation, true);
      expect(notifier.state.keepScreenAwake, true);

      notifier.toggleShareRealTimeLocation(false);
      notifier.toggleKeepScreenAwake(false);

      expect(notifier.state.shareRealTimeLocation, false);
      expect(notifier.state.keepScreenAwake, false);
    });
  });
}
