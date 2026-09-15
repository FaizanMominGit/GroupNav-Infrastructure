enum PacketType {
  telemetry,
  ack,
  alert;

  String get label {
    switch (this) {
      case PacketType.telemetry:
        return 'TELEMETRY';
      case PacketType.ack:
        return 'ACK';
      case PacketType.alert:
        return 'ALERT';
    }
  }
}

class MqttLogPacket {
  final DateTime timestamp;
  final String topic;
  final String payload;
  final PacketType type;
  final int qos;

  const MqttLogPacket({
    required this.timestamp,
    required this.topic,
    required this.payload,
    required this.type,
    this.qos = 1,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

class MetricSummary {
  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final double? loadPercentage;
  final bool isOptimal;

  const MetricSummary({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    this.loadPercentage,
    this.isOptimal = true,
  });
}

class PipelineHealthState {
  final int latencyMs;
  final String region;
  final bool isHealthy;
  final int lambdaInvocationsPerMin;
  final int redisUsedMemoryMb;
  final int redisTotalMemoryMb;
  final int dlqMessageDepth;
  final int mqttIngestRatePktsPerSec;
  final List<MqttLogPacket> logPackets;
  final bool isStreaming;
  final String dashboardUrl;

  const PipelineHealthState({
    this.latencyMs = 14,
    this.region = 'ap-south-1',
    this.isHealthy = true,
    this.lambdaInvocationsPerMin = 4820,
    this.redisUsedMemoryMb = 412,
    this.redisTotalMemoryMb = 1536,
    this.dlqMessageDepth = 0,
    this.mqttIngestRatePktsPerSec = 1240,
    this.logPackets = const [],
    this.isStreaming = true,
    this.dashboardUrl =
        'https://ap-south-1.console.aws.amazon.com/cloudwatch/home?region=ap-south-1#dashboards:name=GroupNav-Observability-Dashboard',
  });

  double get redisLoadPercentage =>
      (redisUsedMemoryMb / redisTotalMemoryMb).clamp(0.0, 1.0);

  PipelineHealthState copyWith({
    int? latencyMs,
    String? region,
    bool? isHealthy,
    int? lambdaInvocationsPerMin,
    int? redisUsedMemoryMb,
    int? redisTotalMemoryMb,
    int? dlqMessageDepth,
    int? mqttIngestRatePktsPerSec,
    List<MqttLogPacket>? logPackets,
    bool? isStreaming,
    String? dashboardUrl,
  }) {
    return PipelineHealthState(
      latencyMs: latencyMs ?? this.latencyMs,
      region: region ?? this.region,
      isHealthy: isHealthy ?? this.isHealthy,
      lambdaInvocationsPerMin:
          lambdaInvocationsPerMin ?? this.lambdaInvocationsPerMin,
      redisUsedMemoryMb: redisUsedMemoryMb ?? this.redisUsedMemoryMb,
      redisTotalMemoryMb: redisTotalMemoryMb ?? this.redisTotalMemoryMb,
      dlqMessageDepth: dlqMessageDepth ?? this.dlqMessageDepth,
      mqttIngestRatePktsPerSec:
          mqttIngestRatePktsPerSec ?? this.mqttIngestRatePktsPerSec,
      logPackets: logPackets ?? this.logPackets,
      isStreaming: isStreaming ?? this.isStreaming,
      dashboardUrl: dashboardUrl ?? this.dashboardUrl,
    );
  }
}
