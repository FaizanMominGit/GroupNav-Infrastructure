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
  String get mockupLabel {
    switch (this) {
      case GpsRate.oneHz:
        return 'Battery Saver (1s)';
      case GpsRate.fiveHz:
        return 'Standard (500ms)';
      case GpsRate.tenHz:
        return 'High Precision (100ms)';
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

  String get mockupLabel {
    switch (this) {
      case MapThemeMode.day:
        return 'Day';
      case MapThemeMode.night:
        return 'Night';
      case MapThemeMode.system:
        return 'Auto (Sensor)';
    }
  }
}

class RiderSettings {
  final String callsign;
  final String vehicle;
  final String emergencyContact;
  final bool geofenceDepartureWarning;
  final bool speedAlert;
  final bool voiceAudioCues;
  final GpsRate gpsRate;
  final bool backgroundBroadcast;
  final bool highPrecisionGeofenceAlert;
  final UnitSystem unitSystem;
  final MapThemeMode mapThemeMode;
  final bool keepScreenAwake;
  final bool shareRealTimeLocation;
  final bool cohesionPingAudio;
  final double stakedBalanceNav;
  final double navRewardRate;
  final String walletAddress;

  const RiderSettings({
    this.callsign = '0xApex',
    this.vehicle = 'Motorcycle (Ducati Panigale)',
    this.emergencyContact = 'Elena (+1 555-0199)',
    this.geofenceDepartureWarning = true,
    this.speedAlert = true,
    this.voiceAudioCues = true,
    this.gpsRate = GpsRate.fiveHz,
    this.backgroundBroadcast = true,
    this.highPrecisionGeofenceAlert = true,
    this.unitSystem = UnitSystem.metric,
    this.mapThemeMode = MapThemeMode.system,
    this.keepScreenAwake = true,
    this.shareRealTimeLocation = true,
    this.cohesionPingAudio = true,
    this.stakedBalanceNav = 142.8,
    this.navRewardRate = 4.2,
    this.walletAddress = '0x7F2C9B41...E9A3',
  });

  RiderSettings copyWith({
    String? callsign,
    String? vehicle,
    String? emergencyContact,
    bool? geofenceDepartureWarning,
    bool? speedAlert,
    bool? voiceAudioCues,
    GpsRate? gpsRate,
    bool? backgroundBroadcast,
    bool? highPrecisionGeofenceAlert,
    UnitSystem? unitSystem,
    MapThemeMode? mapThemeMode,
    bool? keepScreenAwake,
    bool? shareRealTimeLocation,
    bool? cohesionPingAudio,
    double? stakedBalanceNav,
    double? navRewardRate,
    String? walletAddress,
  }) {
    return RiderSettings(
      callsign: callsign ?? this.callsign,
      vehicle: vehicle ?? this.vehicle,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      geofenceDepartureWarning: geofenceDepartureWarning ?? this.geofenceDepartureWarning,
      speedAlert: speedAlert ?? this.speedAlert,
      voiceAudioCues: voiceAudioCues ?? this.voiceAudioCues,
      gpsRate: gpsRate ?? this.gpsRate,
      backgroundBroadcast: backgroundBroadcast ?? this.backgroundBroadcast,
      highPrecisionGeofenceAlert: highPrecisionGeofenceAlert ?? this.highPrecisionGeofenceAlert,
      unitSystem: unitSystem ?? this.unitSystem,
      mapThemeMode: mapThemeMode ?? this.mapThemeMode,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      shareRealTimeLocation: shareRealTimeLocation ?? this.shareRealTimeLocation,
      cohesionPingAudio: cohesionPingAudio ?? this.cohesionPingAudio,
      stakedBalanceNav: stakedBalanceNav ?? this.stakedBalanceNav,
      navRewardRate: navRewardRate ?? this.navRewardRate,
      walletAddress: walletAddress ?? this.walletAddress,
    );
  }
}
