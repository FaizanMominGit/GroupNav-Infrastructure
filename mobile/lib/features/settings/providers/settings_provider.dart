import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rider_settings.dart';

class SettingsNotifier extends StateNotifier<RiderSettings> {
  SettingsNotifier() : super(const RiderSettings());

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
  }

  void setMapTheme(MapThemeMode theme) {
    state = state.copyWith(mapThemeMode: theme);
  }

  void toggleCohesionPingAudio(bool value) {
    state = state.copyWith(cohesionPingAudio: value);
  }

  void setCallsign(String value) {
    state = state.copyWith(callsign: value);
  }

  void setVehicle(String value) {
    state = state.copyWith(vehicle: value);
  }

  void setEmergencyContact(String value) {
    state = state.copyWith(emergencyContact: value);
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
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, RiderSettings>((ref) {
  return SettingsNotifier();
});
