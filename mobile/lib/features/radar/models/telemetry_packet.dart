class TelemetryPacket {
  final String riderId;
  final String callsign;
  final String packId;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedKmh;
  final double headingDeg;
  final double accuracy;
  final int timestamp;

  const TelemetryPacket({
    required this.riderId,
    required this.callsign,
    required this.packId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speedKmh,
    required this.headingDeg,
    this.accuracy = 4.5,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'riderId': riderId,
    'callsign': callsign,
    'packId': packId,
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'speedKmh': speedKmh,
    'headingDeg': headingDeg,
    'accuracy': accuracy,
    'timestamp': timestamp,
  };

  factory TelemetryPacket.fromJson(Map<String, dynamic> json) {
    return TelemetryPacket(
      riderId: json['riderId'] as String? ?? '',
      callsign: json['callsign'] as String? ?? 'Pilot',
      packId: json['packId'] as String? ?? '804',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 37.7749,
      longitude: (json['longitude'] as num?)?.toDouble() ?? -122.4194,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0.0,
      headingDeg: (json['headingDeg'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 4.5,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
