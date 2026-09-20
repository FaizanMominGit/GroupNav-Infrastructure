class ConvoyPeer {
  final String callsign;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedKmh;
  final double headingDeg;
  final double relativeOffsetMeters;
  final bool isLeader;
  final String beaconColorHex;
  final String? monikerTag;

  const ConvoyPeer({
    required this.callsign,
    required this.latitude,
    required this.longitude,
    this.altitude = 312.0,
    required this.speedKmh,
    required this.headingDeg,
    required this.relativeOffsetMeters,
    this.isLeader = false,
    this.beaconColorHex = '#0066FF',
    this.monikerTag,
  });

  String get offsetFormatted {
    if (callsign.contains('(You)')) {
      return isLeader ? 'Lead' : 'You';
    }
    final absDist = relativeOffsetMeters.abs();
    final sign = relativeOffsetMeters >= 0 ? '+' : '-';
    if (absDist < 15) {
      return isLeader ? 'Lead' : 'With Pack';
    } else if (absDist >= 1000) {
      final km = absDist / 1000.0;
      return '$sign${km.toStringAsFixed(1)}km';
    } else {
      return '$sign${absDist.round()}m';
    }
  }

  ConvoyPeer copyWith({
    String? callsign,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speedKmh,
    double? headingDeg,
    double? relativeOffsetMeters,
    bool? isLeader,
    String? beaconColorHex,
    String? monikerTag,
  }) {
    return ConvoyPeer(
      callsign: callsign ?? this.callsign,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speedKmh: speedKmh ?? this.speedKmh,
      headingDeg: headingDeg ?? this.headingDeg,
      relativeOffsetMeters: relativeOffsetMeters ?? this.relativeOffsetMeters,
      isLeader: isLeader ?? this.isLeader,
      beaconColorHex: beaconColorHex ?? this.beaconColorHex,
      monikerTag: monikerTag ?? this.monikerTag,
    );
  }
}
