/// Model representing an authenticated Google/Firebase user.
class FirebridgeUser {
  /// Unique Google user ID (sub).
  final String id;

  /// User primary email address.
  final String email;

  /// User display name.
  final String displayName;

  /// Profile photo URL, if available.
  final String? photoUrl;

  /// OAuth2 Access Token used for Google Cloud REST API calls.
  final String accessToken;

  /// OpenID Connect ID Token, if returned by auth flow.
  final String? idToken;

  /// Instant when the current access token expires.
  final DateTime? tokenExpiry;

  const FirebridgeUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.accessToken,
    this.idToken,
    this.tokenExpiry,
  });

  /// True if the access token is missing, expired, or will expire within 60 seconds.
  bool get isTokenExpired {
    if (tokenExpiry == null) return false;
    return DateTime.now().add(const Duration(seconds: 60)).isAfter(tokenExpiry!);
  }

  /// Creates a copy with optional updated fields.
  FirebridgeUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? accessToken,
    String? idToken,
    DateTime? tokenExpiry,
  }) {
    return FirebridgeUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      accessToken: accessToken ?? this.accessToken,
      idToken: idToken ?? this.idToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
    );
  }

  /// Converts this user to a JSON-serializable Map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'accessToken': accessToken,
        'idToken': idToken,
        'tokenExpiry': tokenExpiry?.toIso8601String(),
      };

  /// Constructs a user from a JSON Map.
  factory FirebridgeUser.fromJson(Map<String, dynamic> json) {
    DateTime? expiry;
    if (json['tokenExpiry'] != null) {
      try {
        expiry = DateTime.parse(json['tokenExpiry'] as String);
      } catch (_) {
        expiry = null;
      }
    }

    return FirebridgeUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      accessToken: json['accessToken'] as String? ?? '',
      idToken: json['idToken'] as String?,
      tokenExpiry: expiry,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebridgeUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          accessToken == other.accessToken;

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ accessToken.hashCode;

  @override
  String toString() =>
      'FirebridgeUser(id: $id, email: $email, displayName: $displayName, expired: $isTokenExpired)';
}

