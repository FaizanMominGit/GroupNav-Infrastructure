import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/client_config.dart';
import '../models/pilot_profile.dart';

abstract class AuthStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class SecureAuthStorage implements AuthStorage {
  final FlutterSecureStorage _storage;
  const SecureAuthStorage([this._storage = const FlutterSecureStorage()]);

  @override
  Future<void> write({required String key, required String value}) => _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class MemoryAuthStorage implements AuthStorage {
  final Map<String, String> _map = {};

  @override
  Future<void> write({required String key, required String value}) async => _map[key] = value;

  @override
  Future<String?> read({required String key}) async => _map[key];

  @override
  Future<void> delete({required String key}) async => _map.remove(key);
}

class CognitoAuthService {
  final ClientConfig config;
  final AuthStorage secureStorage;

  static const String _keyPilot = 'groupnav_pilot_profile';
  static const String _keyCredentials = 'groupnav_aws_credentials';
  static const String _keyIdToken = 'groupnav_id_token';
  static const String _keyAccessToken = 'groupnav_access_token';

  CognitoAuthService({
    required this.config,
    AuthStorage? storage,
  }) : secureStorage = storage ?? const SecureAuthStorage();

  /// Register a new user in AWS Cognito User Pool
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String callsign,
  }) async {
    final endpoint = Uri.parse('https://cognito-idp.${config.region}.amazonaws.com/');

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.SignUp',
      },
      body: json.encode({
        'ClientId': config.cognito.userPoolClientId,
        'Username': email.trim(),
        'Password': password,
        'UserAttributes': [
          {'Name': 'email', 'Value': email.trim()},
          {'Name': 'name', 'Value': callsign.trim()},
        ],
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final errorType = (data['__type'] as String? ?? '').split('#').last;
      final message = data['message'] as String? ?? 'Sign up failed';
      throw Exception('AWS Cognito [$errorType]: $message');
    }

    return {
      'userConfirmed': data['UserConfirmed'] as bool? ?? false,
      'userSub': data['UserSub'] as String? ?? '',
    };
  }

  /// Confirm user email registration with 6-digit confirmation code
  Future<bool> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    final endpoint = Uri.parse('https://cognito-idp.${config.region}.amazonaws.com/');

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmSignUp',
      },
      body: json.encode({
        'ClientId': config.cognito.userPoolClientId,
        'Username': email.trim(),
        'ConfirmationCode': confirmationCode.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final errorType = (data['__type'] as String? ?? '').split('#').last;
      final message = data['message'] as String? ?? 'Confirmation failed';
      throw Exception('AWS Cognito [$errorType]: $message');
    }

    return true;
  }

  /// Resend confirmation code to user's email
  Future<void> resendConfirmationCode({required String email}) async {
    final endpoint = Uri.parse('https://cognito-idp.${config.region}.amazonaws.com/');

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.ResendConfirmationCode',
      },
      body: json.encode({
        'ClientId': config.cognito.userPoolClientId,
        'Username': email.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final errorType = (data['__type'] as String? ?? '').split('#').last;
      final message = data['message'] as String? ?? 'Resend failed';
      throw Exception('AWS Cognito [$errorType]: $message');
    }
  }

  /// Initiate password reset flow by sending a 6-digit confirmation code to user's email
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final endpoint = Uri.parse('https://cognito-idp.${config.region}.amazonaws.com/');

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.ForgotPassword',
      },
      body: json.encode({
        'ClientId': config.cognito.userPoolClientId,
        'Username': email.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final errorType = (data['__type'] as String? ?? '').split('#').last;
      final message = data['message'] as String? ?? 'Password reset request failed';
      throw Exception('AWS Cognito [$errorType]: $message');
    }

    final deliveryDetails = data['CodeDeliveryDetails'] as Map<String, dynamic>? ?? {};
    return {
      'destination': deliveryDetails['Destination'] as String? ?? email,
      'deliveryMedium': deliveryDetails['DeliveryMedium'] as String? ?? 'EMAIL',
      'attributeName': deliveryDetails['AttributeName'] as String? ?? 'email',
    };
  }

  /// Confirm password reset with the 6-digit email confirmation code and new password
  Future<bool> confirmForgotPassword({
    required String email,
    required String confirmationCode,
    required String newPassword,
  }) async {
    final endpoint = Uri.parse('https://cognito-idp.${config.region}.amazonaws.com/');

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmForgotPassword',
      },
      body: json.encode({
        'ClientId': config.cognito.userPoolClientId,
        'Username': email.trim(),
        'ConfirmationCode': confirmationCode.trim(),
        'Password': newPassword,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final errorType = (data['__type'] as String? ?? '').split('#').last;
      final message = data['message'] as String? ?? 'Password confirmation failed';
      throw Exception('AWS Cognito [$errorType]: $message');
    }

    return true;
  }

  /// Authenticate user via USER_PASSWORD_AUTH and exchange ID token for temporary AWS IAM credentials
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
    String? callsign,
    String vehicleClass = 'SPORT',
    String beaconColor = '#0050CB',
  }) async {
    final idpEndpoint = Uri.parse('https://cognito-idp.${config.region}.amazonaws.com/');

    final authResponse = await http.post(
      idpEndpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
      },
      body: json.encode({
        'AuthFlow': 'USER_PASSWORD_AUTH',
        'ClientId': config.cognito.userPoolClientId,
        'AuthParameters': {
          'USERNAME': email.trim(),
          'PASSWORD': password,
        },
      }),
    ).timeout(const Duration(seconds: 15));

    final authData = json.decode(authResponse.body) as Map<String, dynamic>;
    if (authResponse.statusCode != 200) {
      final errorType = (authData['__type'] as String? ?? '').split('#').last;
      final message = authData['message'] as String? ?? 'Authentication failed';
      throw Exception('AWS Cognito [$errorType]: $message');
    }

    final authResult = authData['AuthenticationResult'] as Map<String, dynamic>?;
    if (authResult == null) {
      throw Exception('AWS Cognito: Missing AuthenticationResult in response');
    }

    final idToken = authResult['IdToken'] as String;
    final accessToken = authResult['AccessToken'] as String;

    // Decode ID token to extract user attributes
    final tokenClaims = _decodeJwtPayload(idToken);
    final userSub = tokenClaims['sub'] as String? ?? '';
    final resolvedCallsign = callsign ?? tokenClaims['name'] as String? ?? email.split('@').first;

    // Exchange Cognito ID Token for real AWS temporary IAM credentials from Cognito Identity Pool
    final identityEndpoint = Uri.parse('https://cognito-identity.${config.region}.amazonaws.com/');
    final providerKey = 'cognito-idp.${config.region}.amazonaws.com/${config.cognito.userPoolId}';

    // 1. Get Identity ID
    final getIdResponse = await http.post(
      identityEndpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityService.GetId',
      },
      body: json.encode({
        'IdentityPoolId': config.cognito.identityPoolId,
        'Logins': {
          providerKey: idToken,
        },
      }),
    ).timeout(const Duration(seconds: 15));

    final getIdData = json.decode(getIdResponse.body) as Map<String, dynamic>;
    if (getIdResponse.statusCode != 200) {
      final errorType = (getIdData['__type'] as String? ?? '').split('#').last;
      final message = getIdData['message'] as String? ?? 'Failed to retrieve Cognito Identity ID';
      throw Exception('AWS Cognito Identity [$errorType]: $message');
    }

    final identityId = getIdData['IdentityId'] as String;

    // 2. Get Credentials For Identity
    final getCredsResponse = await http.post(
      identityEndpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityService.GetCredentialsForIdentity',
      },
      body: json.encode({
        'IdentityId': identityId,
        'Logins': {
          providerKey: idToken,
        },
      }),
    ).timeout(const Duration(seconds: 15));

    final getCredsData = json.decode(getCredsResponse.body) as Map<String, dynamic>;
    if (getCredsResponse.statusCode != 200) {
      final errorType = (getCredsData['__type'] as String? ?? '').split('#').last;
      final message = getCredsData['message'] as String? ?? 'Failed to retrieve AWS credentials';
      throw Exception('AWS Cognito Identity [$errorType]: $message');
    }

    final creds = getCredsData['Credentials'] as Map<String, dynamic>;
    final awsCredentials = {
      'AccessKeyId': creds['AccessKeyId'] as String,
      'SecretKey': creds['SecretKey'] as String,
      'SessionToken': creds['SessionToken'] as String,
      if (creds['Expiration'] != null) 'Expiration': creds['Expiration'].toString(),
    };

    final pilot = PilotProfile(
      phoneOrEmail: email.trim(),
      callsign: resolvedCallsign,
      vehicleClass: vehicleClass,
      beaconColor: beaconColor,
      cognitoIdentityId: identityId,
      cognitoSub: userSub,
    );

    // Save to secure device storage
    await secureStorage.write(key: _keyPilot, value: json.encode(pilot.toJson()));
    await secureStorage.write(key: _keyCredentials, value: json.encode(awsCredentials));
    await secureStorage.write(key: _keyIdToken, value: idToken);
    await secureStorage.write(key: _keyAccessToken, value: accessToken);

    debugPrint('[CognitoAuthService] Real AWS credentials acquired successfully for $email');

    return {
      'pilot': pilot,
      'awsCredentials': awsCredentials,
    };
  }

  /// Restore saved session from secure device keystore
  Future<PilotProfile?> restoreSession() async {
    final rawPilot = await secureStorage.read(key: _keyPilot);
    if (rawPilot == null) return null;

    try {
      final jsonMap = json.decode(rawPilot) as Map<String, dynamic>;
      return PilotProfile.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  /// Retrieve active AWS credentials from storage
  Future<Map<String, String>?> getCachedCredentials() async {
    final rawCreds = await secureStorage.read(key: _keyCredentials);
    if (rawCreds == null) return null;

    try {
      final jsonMap = json.decode(rawCreds) as Map<String, dynamic>;
      return jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return null;
    }
  }

  /// Sign out and clear stored credentials
  Future<void> signOut() async {
    await secureStorage.delete(key: _keyPilot);
    await secureStorage.delete(key: _keyCredentials);
    await secureStorage.delete(key: _keyIdToken);
    await secureStorage.delete(key: _keyAccessToken);
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final normalized = base64Url.normalize(parts[1]);
      final resp = utf8.decode(base64Url.decode(normalized));
      return json.decode(resp) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
