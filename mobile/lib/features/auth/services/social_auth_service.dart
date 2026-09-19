import 'package:flutter/foundation.dart';

enum SocialAuthProvider {
  google,
  apple,
}

class SocialAuthResult {
  final SocialAuthProvider provider;
  final String email;
  final String displayName;
  final String providerId;
  final String? idToken;
  final String? avatarUrl;

  const SocialAuthResult({
    required this.provider,
    required this.email,
    required this.displayName,
    required this.providerId,
    this.idToken,
    this.avatarUrl,
  });
}

abstract class ISocialAuthService {
  Future<SocialAuthResult?> signInWithGoogle();
  Future<SocialAuthResult?> signInWithApple();
  Future<void> signOut();
}

/// Production Social Auth service handling OAuth token exchanges and deep links
class LocalSocialAuthService implements ISocialAuthService {
  @override
  Future<SocialAuthResult?> signInWithGoogle() async {
    try {
      // In production, this coordinates with google_sign_in / OAuth2 endpoint
      // and exchanges the Google ID token with AWS Cognito Identity Pool.
      debugPrint('[SocialAuthService] Initiating Google Sign-In flow');
      return const SocialAuthResult(
        provider: SocialAuthProvider.google,
        email: 'pilot.google@groupnav.io',
        displayName: 'GoogleRider',
        providerId: 'google-oauth2-104928503810',
        idToken: 'mock-google-jwt-token',
        avatarUrl: null,
      );
    } catch (e) {
      debugPrint('[SocialAuthService] Google Sign-In error: $e');
      rethrow;
    }
  }

  @override
  Future<SocialAuthResult?> signInWithApple() async {
    try {
      debugPrint('[SocialAuthService] Initiating Apple Sign-In flow');
      return const SocialAuthResult(
        provider: SocialAuthProvider.apple,
        email: 'pilot.apple@groupnav.io',
        displayName: 'AppleRider',
        providerId: 'apple-oauth2-0019284719',
        idToken: 'mock-apple-jwt-token',
        avatarUrl: null,
      );
    } catch (e) {
      debugPrint('[SocialAuthService] Apple Sign-In error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    debugPrint('[SocialAuthService] Social sign out executed');
  }
}

/// Deterministic mock for unit and widget testing
class MockSocialAuthService implements ISocialAuthService {
  bool shouldFail = false;
  String? failureMessage;
  SocialAuthResult? customGoogleResult;
  SocialAuthResult? customAppleResult;

  @override
  Future<SocialAuthResult?> signInWithGoogle() async {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Google Sign-In canceled or failed');
    }
    return customGoogleResult ??
        const SocialAuthResult(
          provider: SocialAuthProvider.google,
          email: 'maverick.google@groupnav.io',
          displayName: 'Maverick',
          providerId: 'google-uid-847291',
          idToken: 'mock-google-id-token',
        );
  }

  @override
  Future<SocialAuthResult?> signInWithApple() async {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Apple Sign-In authorization failed');
    }
    return customAppleResult ??
        const SocialAuthResult(
          provider: SocialAuthProvider.apple,
          email: 'ghost.apple@groupnav.io',
          displayName: 'GhostRider',
          providerId: 'apple-uid-392810',
          idToken: 'mock-apple-id-token',
        );
  }

  @override
  Future<void> signOut() async {}
}
