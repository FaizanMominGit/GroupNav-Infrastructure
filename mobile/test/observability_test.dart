import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/features/observability/models/pipeline_metrics.dart';
import 'package:groupnav_mobile/features/observability/providers/observability_provider.dart';

void main() {
  group('PipelineMetrics Model Tests', () {
    test('PacketType returns accurate uppercase telemetry tags', () {
      expect(PacketType.telemetry.label, 'TELEMETRY');
      expect(PacketType.ack.label, 'ACK');
      expect(PacketType.alert.label, 'ALERT');
    });

    test('MqttLogPacket formats timestamp string accurately', () {
      final time = DateTime(2024, 10, 15, 14, 35, 22, 123);
      final packet = MqttLogPacket(
        timestamp: time,
        topic: 'groupnav/convoy/804/telemetry',
        payload: '{"speed": 82}',
        type: PacketType.telemetry,
      );

      expect(packet.formattedTime, '14:35:22.123');
      expect(packet.qos, 1);
    });

    test('PipelineHealthState computes Redis load percentage accurately', () {
      const state = PipelineHealthState(
        redisUsedMemoryMb: 512,
        redisTotalMemoryMb: 2048,
      );
      expect(state.redisLoadPercentage, 0.25);
    });

    test('PipelineHealthState copyWith preserves defaults and updates fields', () {
      const state = PipelineHealthState();
      expect(state.region, 'ap-south-1');
      expect(state.isHealthy, true);

      final updated = state.copyWith(
        latencyMs: 24,
        isHealthy: false,
        dlqMessageDepth: 2,
      );

      expect(updated.latencyMs, 24);
      expect(updated.isHealthy, false);
      expect(updated.dlqMessageDepth, 2);
      expect(updated.region, 'ap-south-1');
    });
  });

  group('ObservabilityNotifier State Management Tests', () {
    test('Initializes with default telemetry log buffer', () {
      final notifier = ObservabilityNotifier();
      expect(notifier.state.logPackets.isNotEmpty, true);
      expect(notifier.state.isStreaming, true);
      expect(notifier.state.latencyMs, 14);
      expect(notifier.state.dashboardUrl.contains('GroupNav-Observability-Dashboard'), true);
      notifier.dispose();
    });

    test('toggleStreaming toggles streaming boolean', () {
      final notifier = ObservabilityNotifier();
      expect(notifier.state.isStreaming, true);

      notifier.toggleStreaming();
      expect(notifier.state.isStreaming, false);

      notifier.toggleStreaming();
      expect(notifier.state.isStreaming, true);
      notifier.dispose();
    });

    test('clearLogs flushes all packets from memory buffer', () {
      final notifier = ObservabilityNotifier();
      expect(notifier.state.logPackets.isNotEmpty, true);

      notifier.clearLogs();
      expect(notifier.state.logPackets.isEmpty, true);
      notifier.dispose();
    });

    test('addPacket prepends new telemetry records and respects max capacity', () {
      final notifier = ObservabilityNotifier();
      notifier.clearLogs();

      final newPkt = MqttLogPacket(
        timestamp: DateTime.now(),
        topic: 'groupnav/test',
        payload: '{"test": true}',
        type: PacketType.ack,
      );

      notifier.addPacket(newPkt);
      expect(notifier.state.logPackets.length, 1);
      expect(notifier.state.logPackets.first.topic, 'groupnav/test');

      // Test buffer cap at 100
      for (int i = 0; i < 110; i++) {
        notifier.addPacket(newPkt);
      }
      expect(notifier.state.logPackets.length, 100);
      notifier.dispose();
    });

    test('refreshMetrics fluctuates values within operational bounds', () {
      final notifier = ObservabilityNotifier();
      notifier.refreshMetrics();

      expect(notifier.state.latencyMs >= 10 && notifier.state.latencyMs <= 25, true);
      expect(notifier.state.lambdaInvocationsPerMin >= 4700, true);
      expect(notifier.state.mqttIngestRatePktsPerSec >= 1200, true);
      notifier.dispose();
    });
  });
}
