import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/pipeline_metrics.dart';

class LiveTerminalConsole extends StatelessWidget {
  final List<MqttLogPacket> packets;
  final bool isStreaming;
  final VoidCallback onToggleStreaming;
  final VoidCallback onClearLogs;

  const LiveTerminalConsole({
    super.key,
    required this.packets,
    required this.isStreaming,
    required this.onToggleStreaming,
    required this.onClearLogs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkMapCanvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // macOS Terminal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF30363D), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Red, Yellow, Green Window Dots
                _buildDot(const Color(0xFFFF5F56)),
                const SizedBox(width: 6),
                _buildDot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 6),
                _buildDot(const Color(0xFF27C93F)),
                const SizedBox(width: 12),

                // Terminal Title
                Expanded(
                  child: Text(
                    'mqtt-broker::stream-in',
                    style: AppTypography.bodySm.copyWith(
                      fontFamily: 'monospace',
                      color: const Color(0xFFC9D1D9),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),

                // Live Streaming Indicator Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isStreaming
                        ? AppColors.telemetryEmerald.withOpacity(0.15)
                        : AppColors.alertWarning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isStreaming
                          ? AppColors.telemetryEmerald.withOpacity(0.4)
                          : AppColors.alertWarning.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isStreaming
                              ? AppColors.telemetryEmerald
                              : AppColors.alertWarning,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isStreaming ? 'LIVE' : 'PAUSED',
                        style: TextStyle(
                          color: isStreaming
                              ? AppColors.telemetryEmerald
                              : AppColors.alertWarning,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrolling Log Body
          SizedBox(
            height: 220,
            child: packets.isEmpty
                ? Center(
                    child: Text(
                      'No active MQTT packets in buffer.',
                      style: AppTypography.bodySm.copyWith(
                        color: const Color(0xFF8B949E),
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: packets.length,
                    itemBuilder: (context, index) {
                      final pkt = packets[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pkt.formattedTime,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF8B949E),
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF21262D),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pkt.type.label,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: pkt.type == PacketType.telemetry
                                          ? AppColors.routeCyan
                                          : AppColors.secondaryFixed,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    pkt.topic,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFF58A6FF),
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text(
                                pkt.payload,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: pkt.type == PacketType.ack
                                      ? const Color(0xFF7EE787)
                                      : const Color(0xFFE6EDF3),
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Terminal Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
              border: Border(
                top: BorderSide(color: Color(0xFF30363D), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'buffer: ${packets.length} pkts • QoS 1',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF8B949E),
                    fontSize: 10,
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: onToggleStreaming,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              isStreaming ? Icons.pause : Icons.play_arrow,
                              size: 14,
                              color: const Color(0xFFC9D1D9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isStreaming ? 'Pause' : 'Resume',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFFC9D1D9),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onClearLogs,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF8B949E),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _copyLog(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Icon(
                          Icons.copy,
                          size: 13,
                          color: Color(0xFFC9D1D9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  void _copyLog(BuildContext context) {
    final text = packets.map((p) => '[${p.formattedTime}] ${p.topic}: ${p.payload}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('MQTT log buffer copied to clipboard'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
