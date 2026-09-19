import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/rider_settings.dart';

class SettingsNotifier extends StateNotifier<RiderSettings> {
  static const _storage = FlutterSecureStorage();
  static const _keyEmergencyContact = 'groupnav_emergency_contact';
  static const _keyVehicle = 'groupnav_vehicle';
  static const _keyCallsign = 'groupnav_callsign';
  static const _keyUnitSystem = 'groupnav_unit_system';

  SettingsNotifier() : super(const RiderSettings()) {
    _restoreSavedSettings();
  }

  Future<void> _restoreSavedSettings() async {
    try {
      final contact = await _storage.read(key: _keyEmergencyContact);
      final vehicle = await _storage.read(key: _keyVehicle);
      final callsign = await _storage.read(key: _keyCallsign);
      final unitStr = await _storage.read(key: _keyUnitSystem);

      state = state.copyWith(
        emergencyContact: contact ?? state.emergencyContact,
        vehicle: vehicle ?? state.vehicle,
        callsign: (callsign != null && callsign.isNotEmpty) ? callsign : state.callsign,
        unitSystem: unitStr == 'imperial' ? UnitSystem.imperial : UnitSystem.metric,
      );
    } catch (_) {
      // Native storage not available in pure unit test environments
    }
  }

  void setGpsRate(GpsRate rate) {
    state = state.copyWith(gpsRate: rate);
  }

  void toggleBackgroundBroadcast(bool value) {
    state = state.copyWith(backgroundBroadcast: value);
  }

  void toggleHighPrecisionAlert(bool value) {
    state = state.copyWith(highPrecisionGeofenceAlert: value);
  }

  void setUnitSystem(UnitSystem unit) {
    state = state.copyWith(unitSystem: unit);
    _safeWrite(_keyUnitSystem, unit == UnitSystem.imperial ? 'imperial' : 'metric');
  }

  void setMapTheme(MapThemeMode theme) {
    state = state.copyWith(mapThemeMode: theme);
  }

  void toggleCohesionPingAudio(bool value) {
    state = state.copyWith(cohesionPingAudio: value);
  }

  void setCallsign(String value) {
    state = state.copyWith(callsign: value);
    _safeWrite(_keyCallsign, value);
  }

  void setVehicle(String value) {
    state = state.copyWith(vehicle: value);
    _safeWrite(_keyVehicle, value);
  }

  void setEmergencyContact(String value) {
    state = state.copyWith(emergencyContact: value);
    _safeWrite(_keyEmergencyContact, value);
  }

  void toggleGeofenceDepartureWarning(bool value) {
    state = state.copyWith(geofenceDepartureWarning: value);
  }

  void toggleSpeedAlert(bool value) {
    state = state.copyWith(speedAlert: value);
  }

  void toggleVoiceAudioCues(bool value) {
    state = state.copyWith(voiceAudioCues: value);
  }

  void toggleKeepScreenAwake(bool value) {
    state = state.copyWith(keepScreenAwake: value);
  }

  void toggleShareRealTimeLocation(bool value) {
    state = state.copyWith(shareRealTimeLocation: value);
  }

  void toggleDemoSimulation(bool value) {
    state = state.copyWith(isDemoSimulation: value);
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Native storage not available in pure unit test environments
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, RiderSettings>((ref) {
  return SettingsNotifier();
});
