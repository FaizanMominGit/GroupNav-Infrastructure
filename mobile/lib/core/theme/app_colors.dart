import 'package:flutter/material.dart';

/// Convoy Telemetry Design Tokens — Colors (groupnav_template.md)
abstract class AppColors {
  // Primary brand anchors
  static const Color primary = Color(0xFF0066FF);
  static const Color primaryDark = Color(0xFF0050CB);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFFDAE1FF);
  static const Color primaryFixedDim = Color(0xFFB3C5FF);
  static const Color onPrimaryFixed = Color(0xFF001849);
  static const Color onPrimaryFixedVariant = Color(0xFF003FA4);

  // Secondary & Telemetry Accents
  static const Color telemetryEmerald = Color(0xFF00C48C);
  static const Color routeCyan = Color(0xFF00D4FF);
  static const Color secondary = Color(0xFF006C4B);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF60F9BD);
  static const Color onSecondaryContainer = Color(0xFF00714F);
  static const Color secondaryFixed = Color(0xFF63FCC0);
  static const Color onSecondaryFixedVariant = Color(0xFF005138);

  // Alerts & System States
  static const Color alertWarning = Color(0xFFFF9500);
  static const Color alertCritical = Color(0xFFFF3B30);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Surfaces & Backgrounds
  static const Color surface = Color(0xFFFAF8FF);
  static const Color surfaceDim = Color(0xFFD8D9E6);
  static const Color surfaceBright = Color(0xFFFAF8FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F3FF);
  static const Color surfaceContainer = Color(0xFFECEDFA);
  static const Color surfaceContainerHigh = Color(0xFFE6E7F4);
  static const Color surfaceContainerHighest = Color(0xFFE1E2EE);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color mapSurface = Color(0xFFF4F6F8);
  static const Color darkMapCanvas = Color(0xFF0D1117);

  // High-Contrast Slate Typography
  static const Color textPrimary = Color(0xFF1A1D20);
  static const Color textSecondary = Color(0xFF636A73);
  static const Color onSurface = Color(0xFF191B24);
  static const Color onSurfaceVariant = Color(0xFF424656);
  static const Color inverseSurface = Color(0xFF2E303A);
  static const Color inverseOnSurface = Color(0xFFEFF0FD);

  // Borders & Outlines
  static const Color borderSubtle = Color(0xFFE5E8EB);
  static const Color outline = Color(0xFF727687);
  static const Color outlineVariant = Color(0xFFC2C6D8);
}
