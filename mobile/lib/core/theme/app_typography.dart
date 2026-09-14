import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Convoy Telemetry Typography Scale (Inter Font Family)
abstract class AppTypography {
  static TextStyle get headlineXl => GoogleFonts.inter(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 32,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineLg => GoogleFonts.inter(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.015 * 24,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMd => GoogleFonts.inter(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01 * 20,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLg => GoogleFonts.inter(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMd => GoogleFonts.inter(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySm => GoogleFonts.inter(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get labelLg => GoogleFonts.inter(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.01 * 14,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelMd => GoogleFonts.inter(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.02 * 12,
    color: AppColors.textSecondary,
  );

  static TextStyle get labelSm => GoogleFonts.inter(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.04 * 11,
    color: AppColors.textSecondary,
  );

  /// Dedicated tabular numerals for coordinates, speed, and DePIN tickers
  static TextStyle get telemetryNum => GoogleFonts.inter(
    fontSize: 18,
    height: 22 / 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 18,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );
}
