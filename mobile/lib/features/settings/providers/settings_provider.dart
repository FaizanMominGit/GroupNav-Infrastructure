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
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, RiderSettings>((ref) {
  return SettingsNotifier();
});
