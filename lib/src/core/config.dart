import 'constants.dart';

/// Configuration options for the Firebridge BYOC client.
class FirebridgeConfig {
  /// Whether internal operational logs are output to the console.
  final bool enableLogging;

  /// Google OAuth 2.0 Web Client ID (Required for Flutter Web).
  final String? webClientId;

  /// Default Firestore regional location ID for newly created databases (e.g. 'nam5', 'us-central1').
  final String defaultRegion;

  /// Delegated OAuth scopes requested during authentication.
  final List<String> scopes;

  const FirebridgeConfig({
    this.enableLogging = false,
    this.webClientId,
    this.defaultRegion = 'nam5',
    this.scopes = FirebridgeConstants.defaultScopes,
  });

  FirebridgeConfig copyWith({
    bool? enableLogging,
    String? webClientId,
    String? defaultRegion,
    List<String>? scopes,
  }) {
    return FirebridgeConfig(
      enableLogging: enableLogging ?? this.enableLogging,
      webClientId: webClientId ?? this.webClientId,
      defaultRegion: defaultRegion ?? this.defaultRegion,
      scopes: scopes ?? this.scopes,
    );
  }
}

