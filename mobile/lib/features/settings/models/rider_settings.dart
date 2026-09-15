enum GpsRate {
  oneHz,
  fiveHz,
  tenHz;

  String get label {
    switch (this) {
      case GpsRate.oneHz:
        return '1 Hz (Battery Saver)';
      case GpsRate.fiveHz:
        return '5 Hz (Balanced)';
      case GpsRate.tenHz:
        return '10 Hz (Pro Convoy)';
    }
  }

  String get shortLabel {
    switch (this) {
      case GpsRate.oneHz:
        return '1 Hz';
      case GpsRate.fiveHz:
        return '5 Hz';
      case GpsRate.tenHz:
        return '10 Hz';
    }
  }

  Duration get intervalDuration {
    switch (this) {
      case GpsRate.oneHz:
        return const Duration(milliseconds: 1000);
      case GpsRate.fiveHz:
        return const Duration(milliseconds: 200);
      case GpsRate.tenHz:
        return const Duration(milliseconds: 100);
    }
  }

  double get distanceFilterMeters {
    switch (this) {
      case GpsRate.oneHz:
        return 5.0;
      case GpsRate.fiveHz:
        return 2.0;
      case GpsRate.tenHz:
        return 0.5;
    }
  }
}

enum UnitSystem {
  metric,
  imperial;

  String get speedUnit => this == UnitSystem.metric ? 'km/h' : 'mph';
  String get distanceUnit => this == UnitSystem.metric ? 'meters' : 'feet';
  String get longDistanceUnit => this == UnitSystem.metric ? 'km' : 'mi';
  String get label => this == UnitSystem.metric ? 'Metric (km/h)' : 'Imperial (mph)';
}

enum MapThemeMode {
  day,
  night,
  system;

  String get label {
    switch (this) {
      case MapThemeMode.day:
        return 'Day';
      case MapThemeMode.night:
        return 'Night';
      case MapThemeMode.system:
        return 'Auto';
    }
  }
}

class RiderSettings {
  final GpsRate gpsRate;
  final bool backgroundBroadcast;
  final bool highPrecisionGeofenceAlert;
  final UnitSystem unitSystem;
  final MapThemeMode mapThemeMode;
  final bool cohesionPingAudio;
  final double stakedBalanceNav;
  final double navRewardRate;
  final String walletAddress;

  const RiderSettings({
    this.gpsRate = GpsRate.fiveHz,
    this.backgroundBroadcast = true,
    this.highPrecisionGeofenceAlert = true,
    this.unitSystem = UnitSystem.metric,
    this.mapThemeMode = MapThemeMode.system,
    this.cohesionPingAudio = true,
    this.stakedBalanceNav = 142.8,
    this.navRewardRate = 4.2,
    this.walletAddress = '0x7F2C9B41...E9A3',
  });

  RiderSettings copyWith({
    GpsRate? gpsRate,
    bool? backgroundBroadcast,
    bool? highPrecisionGeofenceAlert,
    UnitSystem? unitSystem,
    MapThemeMode? mapThemeMode,
    bool? cohesionPingAudio,
    double? stakedBalanceNav,
    double? navRewardRate,
    String? walletAddress,
  }) {
    return RiderSettings(
      gpsRate: gpsRate ?? this.gpsRate,
      backgroundBroadcast: backgroundBroadcast ?? this.backgroundBroadcast,
      highPrecisionGeofenceAlert: highPrecisionGeofenceAlert ?? this.highPrecisionGeofenceAlert,
      unitSystem: unitSystem ?? this.unitSystem,
      mapThemeMode: mapThemeMode ?? this.mapThemeMode,
      cohesionPingAudio: cohesionPingAudio ?? this.cohesionPingAudio,
      stakedBalanceNav: stakedBalanceNav ?? this.stakedBalanceNav,
      navRewardRate: navRewardRate ?? this.navRewardRate,
      walletAddress: walletAddress ?? this.walletAddress,
    );
  }
}
