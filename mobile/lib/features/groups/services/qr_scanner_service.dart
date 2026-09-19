import 'dart:convert';
import 'package:flutter/foundation.dart';

abstract class IQrScannerService {
  String? parseQrPayload(String raw);
  Future<String?> simulateScan(String code);
}

class ProductionQrScannerService implements IQrScannerService {
  @override
  String? parseQrPayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 1. Check for JSON format: {"action":"join_pack","code":"GN-9482"}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        if (decoded.containsKey('code')) {
          return decoded['code'].toString().trim().toUpperCase();
        }
      } catch (e) {
        debugPrint('[QrScannerService] Failed to parse JSON QR payload: $e');
      }
    }

    // 2. Check for Universal Share Link: https://groupnav.app/join/GN-9482
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments.first.toLowerCase() == 'join' && uri.pathSegments.length >= 2) {
        final seg = uri.pathSegments[1].toUpperCase();
        return seg.startsWith('GN-') || seg.startsWith('PACK-') ? seg : 'GN-$seg';
      }
    }

    // 3. Direct alphanumeric code: GN-XXXX or PACK-XXXX or raw alphanumeric code
    final normalized = trimmed.toUpperCase();
    if (normalized.startsWith('GN-')) {
      return normalized;
    }
    if (normalized.startsWith('PACK-')) {
      return 'GN-${normalized.substring(5)}';
    }

    // Strip non-alphanumeric and format
    final cleanAlphaNum = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleanAlphaNum.length >= 4 && cleanAlphaNum.length <= 8) {
      return 'GN-$cleanAlphaNum';
    }

    return null;
  }

  @override
  Future<String?> simulateScan(String code) async {
    return parseQrPayload(code);
  }
}

class MockQrScannerService implements IQrScannerService {
  String? simulatedResult;
  bool shouldFail = false;

  @override
  String? parseQrPayload(String raw) {
    if (shouldFail) return null;
    if (simulatedResult != null) return simulatedResult;

    final prod = ProductionQrScannerService();
    return prod.parseQrPayload(raw);
  }

  @override
  Future<String?> simulateScan(String code) async {
    if (shouldFail) return null;
    return parseQrPayload(code);
  }
}
