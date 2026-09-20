import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/aws_sigv4_signer.dart';

class IotPolicyService {
  final String apiEndpoint;
  final String region;
  final AwsSigV4Signer _signer;

  IotPolicyService({
    required this.apiEndpoint,
    required this.region,
  }) : _signer = AwsSigV4Signer(region: region, endpoint: Uri.parse(apiEndpoint).host);

  /// Calls the API Gateway to attach the IoT Policy to the current Cognito Identity.
  Future<bool> attachPolicy({
    required String accessKeyId,
    required String secretKey,
    required String sessionToken,
  }) async {
    try {
      final uri = Uri.parse(apiEndpoint);
      // Ensure we hit the correct path. If apiEndpoint is the root URL, append /attach-policy.
      // Usually API Gateway URLs look like https://xyz.execute-api.region.amazonaws.com/prod/attach-policy
      // We will assume the apiEndpoint includes the stage and path.
      
      final host = uri.host;
      final path = uri.path.isEmpty ? '/' : uri.path;

      final body = jsonEncode({});

      final headers = _signer.signRestRequest(
        method: 'POST',
        path: path,
        service: 'execute-api',
        host: host,
        body: body,
        accessKeyId: accessKeyId,
        secretKey: secretKey,
        sessionToken: sessionToken,
      );

      debugPrint('[IotPolicyService] Requesting IoT Policy attachment at $apiEndpoint');
      
      final response = await http.post(
        uri,
        headers: headers,
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[IotPolicyService] Successfully attached IoT policy: ${response.body}');
        return true;
      } else {
        debugPrint('[IotPolicyService] Failed to attach policy: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[IotPolicyService] Exception during policy attachment: $e');
      return false;
    }
  }
}
