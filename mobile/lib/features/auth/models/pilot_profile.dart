class PilotProfile {
  final String phoneOrEmail;
  final String callsign;
  final String vehicleClass;
  final String beaconColor;
  final String? cognitoIdentityId;
  final String? cognitoSub;
  final String? walletAddress;
  final String authProviderType;
  final double navTokenBalance;

  const PilotProfile({
    required this.phoneOrEmail,
    required this.callsign,
    required this.vehicleClass,
    required this.beaconColor,
    this.cognitoIdentityId,
    this.cognitoSub,
    this.walletAddress,
    this.authProviderType = 'cognito',
    this.navTokenBalance = 0.0,
  });

  bool get isWalletConnected => walletAddress != null && walletAddress!.isNotEmpty;

  String? get truncatedWallet {
    if (walletAddress == null || walletAddress!.isEmpty) return null;
    if (walletAddress!.length <= 10) return walletAddress;
    return '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(walletAddress!.length - 4)}';
  }

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
    'walletAddress': walletAddress,
    'authProviderType': authProviderType,
    'navTokenBalance': navTokenBalance,
  };

  factory PilotProfile.fromJson(Map<String, dynamic> json) {
    return PilotProfile(
      phoneOrEmail: json['phoneOrEmail'] as String? ?? '',
      callsign: json['callsign'] as String? ?? 'Pilot',
      vehicleClass: json['vehicleClass'] as String? ?? 'sportbike',
      beaconColor: json['beaconColor'] as String? ?? '#0066FF',
      cognitoIdentityId: json['cognitoIdentityId'] as String?,
      cognitoSub: json['cognitoSub'] as String?,
      walletAddress: json['walletAddress'] as String?,
      authProviderType: json['authProviderType'] as String? ?? 'cognito',
      navTokenBalance: (json['navTokenBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  PilotProfile copyWith({
    String? phoneOrEmail,
    String? callsign,
    String? vehicleClass,
    String? beaconColor,
    String? cognitoIdentityId,
    String? cognitoSub,
    String? walletAddress,
    String? authProviderType,
    double? navTokenBalance,
  }) {
    return PilotProfile(
      phoneOrEmail: phoneOrEmail ?? this.phoneOrEmail,
      callsign: callsign ?? this.callsign,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      beaconColor: beaconColor ?? this.beaconColor,
      cognitoIdentityId: cognitoIdentityId ?? this.cognitoIdentityId,
      cognitoSub: cognitoSub ?? this.cognitoSub,
      walletAddress: walletAddress ?? this.walletAddress,
      authProviderType: authProviderType ?? this.authProviderType,
      navTokenBalance: navTokenBalance ?? this.navTokenBalance,
    );
  }
}
