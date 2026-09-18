import 'dart:convert';
import 'package:crypto/crypto.dart';

class AwsSigV4Signer {
  final String region;
  final String endpoint;

  const AwsSigV4Signer({
    required this.region,
    required this.endpoint,
  });

  /// Generate a presigned WebSocket URL for AWS IoT Core MQTT connection
  String generatePresignedWebSocketUrl({
    required String accessKeyId,
    required String secretKey,
    String? sessionToken,
    DateTime? requestTime,
  }) {
    final now = requestTime?.toUtc() ?? DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatDateTime(now);

    const service = 'iotdevicegateway';
    final credentialScope = '$dateStamp/$region/$service/aws4_request';

    // Query parameters must be sorted alphabetically
    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$accessKeyId/$credentialScope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '86400',
      if (sessionToken != null && sessionToken.isNotEmpty)
        'X-Amz-Security-Token': sessionToken,
      'X-Amz-SignedHeaders': 'host',
    };

    final canonicalQueryString = _buildCanonicalQueryString(queryParams);

    // Canonical Request
    final canonicalRequest = [
      'GET',
      '/mqtt',
      canonicalQueryString,
      'host:$endpoint\n',
      'host',
      sha256.convert(utf8.encode('')).toString(),
    ].join('\n');

    // String to Sign
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    // Key Derivation
    final signingKey = _getSignatureKey(secretKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    return 'wss://$endpoint/mqtt?$canonicalQueryString&X-Amz-Signature=$signature';
  }

  /// Sign an arbitrary HTTP request with AWS SigV4
  Map<String, String> signHttpRequest({
    required String method,
    required String path,
    required String service,
    required String host,
    required String target,
    required String body,
    required String accessKeyId,
    required String secretKey,
    String? sessionToken,
    DateTime? requestTime,
  }) {
    final now = requestTime?.toUtc() ?? DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatDateTime(now);
    final credentialScope = '$dateStamp/$region/$service/aws4_request';

    final payloadHash = sha256.convert(utf8.encode(body)).toString();

    final headersToSign = <String, String>{
      'content-type': 'application/x-amz-json-1.0',
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-target': target,
      if (sessionToken != null && sessionToken.isNotEmpty)
        'x-amz-security-token': sessionToken,
    };

    final sortedHeaderKeys = headersToSign.keys.toList()..sort();
    final canonicalHeaders = sortedHeaderKeys
        .map((k) => '$k:${headersToSign[k]!.trim()}\n')
        .join('');
    final signedHeaders = sortedHeaderKeys.join(';');

    final canonicalRequest = [
      method.toUpperCase(),
      path,
      '', // Canonical query string (empty for POST to DynamoDB)
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(secretKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authHeader = 'AWS4-HMAC-SHA256 '
        'Credential=$accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    return {
      'Content-Type': 'application/x-amz-json-1.0',
      'Host': host,
      'X-Amz-Date': amzDate,
      'X-Amz-Target': target,
      if (sessionToken != null && sessionToken.isNotEmpty)
        'X-Amz-Security-Token': sessionToken,
      'Authorization': authHeader,
    };
  }

  List<int> _getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  String _buildCanonicalQueryString(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    return sortedKeys
        .map((k) => '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(params[k]!)}')
        .join('&');
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)}T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}Z';
  }
}
