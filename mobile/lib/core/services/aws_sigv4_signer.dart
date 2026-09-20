import 'dart:convert';
import 'package:crypto/crypto.dart';

class AwsSigV4Signer {
  final String region;
  final String endpoint;

  const AwsSigV4Signer({
    required this.region,
    required this.endpoint,
  });

  /// Generate a presigned WebSocket URL for AWS IoT Core MQTT connection.
  ///
  /// IMPORTANT: Per AWS IoT Core WebSocket SigV4 spec, the X-Amz-Security-Token
  /// (STS session token) must NOT be included in the canonical query string that
  /// is signed. It must be appended AFTER X-Amz-Signature in the final URL.
  /// See: https://docs.aws.amazon.com/iot/latest/developerguide/mqtt-ws.html
  ///
  /// [port] — The TCP port that will appear in the Host header of the actual
  /// WebSocket upgrade request. Dart's Uri always includes an explicit port when
  /// set (even for the default 443), so the SigV4 canonical host must match.
  /// Pass 443 when using mqtt_client (which calls uri.replace(port:443)), so the
  /// signed "host:endpoint:443" equals the HTTP Host header AWS receives.
  String generatePresignedWebSocketUrl({
    required String accessKeyId,
    required String secretKey,
    String? sessionToken,
    DateTime? requestTime,
    int port = 443,
  }) {
    final now = requestTime?.toUtc() ?? DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatDateTime(now);

    const service = 'iotdevicegateway';
    final credentialScope = '$dateStamp/$region/$service/aws4_request';

    // Step 1: Build the query params for signing — WITHOUT the session token.
    // The session token must be appended AFTER the signature (AWS IoT Core spec).
    final signedQueryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$accessKeyId/$credentialScope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '86400',
      'X-Amz-SignedHeaders': 'host',
    };

    final canonicalQueryString = _buildCanonicalQueryString(signedQueryParams);

    // Step 2: Build the canonical request (session token excluded from signing).
    // AWS IoT Core SigV4 spec requires signing Host: endpoint (hostname only,
    // no port). AWS normalizes Host: endpoint:443 to Host: endpoint for validation.
    final canonicalRequest = [
      'GET',
      '/mqtt',
      canonicalQueryString,
      'host:$endpoint\n',
      'host',
      sha256.convert(utf8.encode('')).toString(),
    ].join('\n');

    // Step 3: String to Sign
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    // Step 4: Derive the signing key and compute the signature
    final signingKey = _getSignatureKey(secretKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    // Step 5: Build the final URL.
    // The URL itself uses the host without port (wss:// default is 443).
    // mqtt_client will inject :443 via uri.replace(port: 443).
    // Append the session token AFTER the signature (required by AWS IoT Core spec).
    var finalUrl = 'wss://$endpoint/mqtt?$canonicalQueryString&X-Amz-Signature=$signature';
    if (sessionToken != null && sessionToken.isNotEmpty) {
      finalUrl += '&X-Amz-Security-Token=${Uri.encodeQueryComponent(sessionToken)}';
    }

    return finalUrl;
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

  /// Sign an AWS REST HTTP request (e.g. Amazon Location Service Routes & Places) with SigV4
  Map<String, String> signRestRequest({
    required String method,
    required String path,
    required String service,
    required String host,
    required String body,
    required String accessKeyId,
    required String secretKey,
    String? sessionToken,
    String contentType = 'application/json',
    Map<String, String>? queryParams,
    DateTime? requestTime,
  }) {
    final now = requestTime?.toUtc() ?? DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatDateTime(now);
    final credentialScope = '$dateStamp/$region/$service/aws4_request';

    final payloadHash = sha256.convert(utf8.encode(body)).toString();

    final canonicalQueryString = queryParams != null && queryParams.isNotEmpty
        ? _buildCanonicalQueryString(queryParams)
        : '';

    final headersToSign = <String, String>{
      'content-type': contentType,
      'host': host,
      'x-amz-date': amzDate,
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
      canonicalQueryString,
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
      'Content-Type': contentType,
      'Host': host,
      'X-Amz-Date': amzDate,
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
