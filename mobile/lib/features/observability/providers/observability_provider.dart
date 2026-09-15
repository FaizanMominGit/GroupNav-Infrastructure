import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pipeline_metrics.dart';

class ObservabilityNotifier extends StateNotifier<PipelineHealthState> {
  Timer? _streamTimer;
  final Random _rng = Random();

  ObservabilityNotifier() : super(_buildInitialState()) {
    _startLogStream();
  }

  static PipelineHealthState _buildInitialState() {
    final now = DateTime.now();
    final initialLogs = [
      MqttLogPacket(
        timestamp: now.subtract(const Duration(seconds: 4)),
        topic: 'aws/iot/events/connections',
        payload: '[AWS-IOT] CONNECT client_id="convoy-edge-mesh-804" clean_session=true',
        type: PacketType.ack,
        qos: 1,
      ),
      MqttLogPacket(
        timestamp: now.subtract(const Duration(seconds: 3)),
        topic: 'groupnav/convoy/804/telemetry',
        payload: '{"riderId":"pilot_apex_01","lat":37.7749,"lng":-122.4194,"speedKmh":82.4,"altitude":312.4,"qos":1}',
        type: PacketType.telemetry,
        qos: 1,
      ),
      MqttLogPacket(
        timestamp: now.subtract(const Duration(seconds: 2)),
        topic: 'groupnav/convoy/804/telemetry',
        payload: '{"riderId":"pilot_viper_02","lat":37.7758,"lng":-122.4182,"speedKmh":80.1,"altitude":311.8,"qos":1}',
        type: PacketType.telemetry,
        qos: 1,
      ),
      MqttLogPacket(
        timestamp: now.subtract(const Duration(seconds: 1)),
        topic: 'groupnav/redis/consensus',
        payload: '[REDIS] HSET convoy:804:positions pilot_apex_01 ttl=60s [OK]',
        type: PacketType.ack,
        qos: 1,
      ),
    ];

    return PipelineHealthState(
      logPackets: initialLogs,
    );
  }

  void toggleStreaming() {
    if (state.isStreaming) {
      _streamTimer?.cancel();
      _streamTimer = null;
      state = state.copyWith(isStreaming: false);
    } else {
      state = state.copyWith(isStreaming: true);
      _startLogStream();
    }
  }

  void clearLogs() {
    state = state.copyWith(logPackets: const []);
  }

  void addPacket(MqttLogPacket packet) {
    final updated = [packet, ...state.logPackets];
    if (updated.length > 100) {
      updated.removeRange(100, updated.length);
    }
    state = state.copyWith(logPackets: updated);
  }

  void refreshMetrics() {
    // Subtle real-time fluctuation around baseline
    final latency = 12 + _rng.nextInt(5);
    final invocations = 4800 + _rng.nextInt(60);
    final redisMem = 410 + _rng.nextInt(8);
    final mqttRate = 1230 + _rng.nextInt(30);

    state = state.copyWith(
      latencyMs: latency,
      lambdaInvocationsPerMin: invocations,
      redisUsedMemoryMb: redisMem,
      mqttIngestRatePktsPerSec: mqttRate,
    );
  }

  void _startLogStream() {
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!state.isStreaming) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final samplePilots = ['pilot_apex_01', 'pilot_viper_02', 'pilot_ghost_03', 'pilot_nomad_04'];
      final chosenPilot = samplePilots[_rng.nextInt(samplePilots.length)];
      final speed = (65.0 + _rng.nextDouble() * 35.0).toStringAsFixed(1);
      final lat = (37.7700 + _rng.nextDouble() * 0.02).toStringAsFixed(4);
      final lng = (-122.4200 + _rng.nextDouble() * 0.02).toStringAsFixed(4);

      final newPacket = MqttLogPacket(
        timestamp: now,
        topic: 'groupnav/convoy/804/telemetry',
        payload: '{"riderId":"$chosenPilot","lat":$lat,"lng":$lng,"speedKmh":$speed,"ts":${now.millisecondsSinceEpoch}}',
        type: PacketType.telemetry,
        qos: 1,
      );

      addPacket(newPacket);
      refreshMetrics();
    });
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }
}

final observabilityProvider =
    StateNotifierProvider<ObservabilityNotifier, PipelineHealthState>((ref) {
  return ObservabilityNotifier();
});
