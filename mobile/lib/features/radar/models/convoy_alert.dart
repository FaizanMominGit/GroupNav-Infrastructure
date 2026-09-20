class ConvoyAlert {
  final String packId;
  final String alertType;
  final String callsign;
  final String message;
  final DateTime timestamp;

  const ConvoyAlert({
    required this.packId,
    required this.alertType,
    required this.callsign,
    required this.message,
    required this.timestamp,
  });

  bool get isSos =>
      alertType.toUpperCase().contains('SOS') ||
      alertType.toUpperCase().contains('EMERGENCY');

  factory ConvoyAlert.fromJson(Map<String, dynamic> json) {
    return ConvoyAlert(
      packId: json['packId'] as String? ?? '',
      alertType: json['alertType'] as String? ?? 'Alert',
      callsign: json['callsign'] as String? ?? 'Rider',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'packId': packId,
        'alertType': alertType,
        'callsign': callsign,
        'message': message,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}
