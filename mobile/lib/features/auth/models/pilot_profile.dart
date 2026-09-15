class PilotProfile {
  final String phoneOrEmail;
  final String callsign;
  final String vehicleClass;
  final String beaconColor;
  final String? cognitoIdentityId;
  final String? cognitoSub;

  const PilotProfile({
    required this.phoneOrEmail,
    required this.callsign,
    required this.vehicleClass,
    required this.beaconColor,
    this.cognitoIdentityId,
    this.cognitoSub,
  });

  int get beaconColorValue {
    try {
      final hex = beaconColor.replaceAll('#', '');
      return int.parse('FF$hex', radix: 16);
    } catch (_) {
      return 0xFF0066FF;
    }
  }

  Map<String, dynamic> toJson() => {
    'phoneOrEmail': phoneOrEmail,
    'callsign': callsign,
    'vehicleClass': vehicleClass,
    'beaconColor': beaconColor,
    'cognitoIdentityId': cognitoIdentityId,
    'cognitoSub': cognitoSub,
  };

  factory PilotProfile.fromJson(Map<String, dynamic> json) {
    return PilotProfile(
      phoneOrEmail: json['phoneOrEmail'] as String? ?? '',
      callsign: json['callsign'] as String? ?? '0xApex',
      vehicleClass: json['vehicleClass'] as String? ?? 'sportbike',
      beaconColor: json['beaconColor'] as String? ?? '#0066FF',
      cognitoIdentityId: json['cognitoIdentityId'] as String?,
      cognitoSub: json['cognitoSub'] as String?,
    );
  }

  PilotProfile copyWith({
    String? phoneOrEmail,
    String? callsign,
    String? vehicleClass,
    String? beaconColor,
    String? cognitoIdentityId,
    String? cognitoSub,
  }) {
    return PilotProfile(
      phoneOrEmail: phoneOrEmail ?? this.phoneOrEmail,
      callsign: callsign ?? this.callsign,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      beaconColor: beaconColor ?? this.beaconColor,
      cognitoIdentityId: cognitoIdentityId ?? this.cognitoIdentityId,
      cognitoSub: cognitoSub ?? this.cognitoSub,
    );
  }
}
