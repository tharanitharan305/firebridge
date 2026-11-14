import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/errors.dart';
import '../core/logger.dart';
import '../models/user.dart';

/// Contract for Firebridge authentication operations.
abstract class FirebridgeAuthService {
  /// The currently signed-in user, or null if unauthenticated.
  FirebridgeUser? get currentUser;

  /// True if a user is currently authenticated with a valid token.
  bool get isSignedIn;

  /// Initiates multiplatform Google Sign-In with configured Cloud and Firebase scopes.
  Future<FirebridgeUser?> signIn();

  /// Direct OAuth access token authenticator (useful for developer testing and web bypass).
  Future<FirebridgeUser> signInWithToken(
    String accessToken, {
    String? email,
    String? displayName,
  });

  /// Signs the user out and clears cached tokens from secure storage.
  Future<void> signOut();

  /// Returns a valid, non-expired access token, refreshing if necessary.
  Future<String> getValidAccessToken();
}

/// Production implementation of [FirebridgeAuthService] using `google_sign_in` and `flutter_secure_storage`.
class FirebridgeAuthServiceImpl with ChangeNotifier implements FirebridgeAuthService {
  static const String _tag = 'AuthService';
  static const String _keyAuthUser = 'firebridge_auth_user';
  static const String _keyAccessToken = 'firebridge_access_token';

  final FirebridgeConfig config;
  final FlutterSecureStorage _storage;
  late final GoogleSignIn _googleSignIn;

  FirebridgeUser? _currentUser;
  bool _isLoading = false;

  FirebridgeAuthServiceImpl({
    required this.config,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage() {
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? config.webClientId : null,
      scopes: config.scopes,
    );
  }

  @override
  FirebridgeUser? get currentUser => _currentUser;

  @override
  bool get isSignedIn =>
      _currentUser != null && _currentUser!.accessToken.isNotEmpty;

  /// True while an authentication operation is in progress.
  bool get isLoading => _isLoading;

  /// Restores cached credentials from secure storage or silent sign-in.
  Future<FirebridgeUser?> restoreSession() async {
    _setLoading(true);
    try {
      // 1. Silent sign-in
      if (!kIsWeb || config.webClientId != null) {
        try {
          final account = await _googleSignIn.signInSilently();
          if (account != null) {
            final auth = await account.authentication;
            if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
              _currentUser = FirebridgeUser(
                id: account.id,
                email: account.email,
                displayName: account.displayName ?? account.email,
                photoUrl: account.photoUrl,
                accessToken: auth.accessToken!,
                idToken: auth.idToken,
                tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
              );
              FirebridgeLogger.i('Restored session via silent sign-in: ${_currentUser!.email}', _tag);
              await _persistSession(_currentUser!);
              return _currentUser;
            }
          }
        } catch (e) {
          FirebridgeLogger.d('Silent sign-in skipped: $e', _tag);
        }
      }

      // 2. Fallback: Restore from secure storage
      final storedJson = await _storage.read(key: _keyAuthUser);
      final storedToken = await _storage.read(key: _keyAccessToken);
      if (storedJson != null && storedToken != null && storedToken.isNotEmpty) {
        try {
          final map = jsonDecode(storedJson) as Map<String, dynamic>;
          _currentUser = FirebridgeUser(
            id: map['id'] as String? ?? '',
            email: map['email'] as String? ?? '',
            displayName: map['displayName'] as String? ?? '',
            photoUrl: map['photoUrl'] as String?,
            accessToken: storedToken,
            tokenExpiry: map['tokenExpiry'] != null
                ? DateTime.tryParse(map['tokenExpiry'] as String)
                : null,
          );
          FirebridgeLogger.i('Restored session from secure storage: ${_currentUser!.email}', _tag);
          return _currentUser;
        } catch (_) {}
      }

      return null;
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<FirebridgeUser?> signIn() async {
    _setLoading(true);
    try {
      if (kIsWeb && (config.webClientId == null || config.webClientId!.isEmpty)) {
        throw const FirebridgeException(
          code: FirebridgeErrorCodes.webClientIdMissing,
          message:
              'Google Sign-In on Web requires an OAuth Web Client ID. '
              'Specify Firebridge.initialize(webClientId: "...") or use signInWithToken().',
          resolutionSteps:
              '1. Go to Google Cloud Console > APIs & Services > Credentials.\n'
              '2. Create an OAuth 2.0 Client ID of type "Web application".\n'
              '3. Pass it to Firebridge.initialize(webClientId: "<client-id>").',
          helpUrl: 'https://console.cloud.google.com/apis/credentials',
        );
      }

      FirebridgeLogger.i('Initiating Google Sign-In with ${config.scopes.length} scopes', _tag);
      final account = await _googleSignIn.signIn();
      if (account == null) {
        FirebridgeLogger.i('User cancelled sign-in flow', _tag);
        return null;
      }

      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw const FirebridgeException(
          code: FirebridgeErrorCodes.unauthenticated,
          message: 'No OAuth access token was returned by Google Sign-In.',
          resolutionSteps: 'Verify OAuth Consent Screen and SHA-1 certificate configuration in Google Cloud Console.',
          helpUrl: 'https://console.cloud.google.com/apis/credentials/consent',
        );
      }

      _currentUser = FirebridgeUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? account.email,
        photoUrl: account.photoUrl,
        accessToken: accessToken,
        idToken: auth.idToken,
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      );

      FirebridgeLogger.i('Signed in successfully: ${_currentUser!.email}', _tag);
      await _persistSession(_currentUser!);
      notifyListeners();
      return _currentUser;
    } on FirebridgeException {
      rethrow;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('appClientId != null') || msg.contains('ClientID not set')) {
        throw const FirebridgeException(
          code: FirebridgeErrorCodes.webClientIdMissing,
          message: 'Google Sign-In Web Client ID is not configured.',
          resolutionSteps: 'Pass your Web Client ID to Firebridge.initialize(webClientId: "...")',
          helpUrl: 'https://console.cloud.google.com/apis/credentials',
        );
      }
      throw FirebridgeException(
        code: FirebridgeErrorCodes.authFailed,
        message: 'Google Sign-In failed: $e',
        details: e,
      );
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<FirebridgeUser> signInWithToken(
    String accessToken, {
    String? email,
    String? displayName,
  }) async {
    _setLoading(true);
    try {
      final token = accessToken.trim();
      FirebridgeLogger.i('Validating direct OAuth access token...', _tag);

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw FirebridgeException.fromResponse(
          response,
          customMessage: 'Invalid or expired direct OAuth access token',
        );
      }

      final userInfo = jsonDecode(response.body) as Map<String, dynamic>;
      final userEmail = userInfo['email'] as String? ?? email ?? 'user@cloud.google.com';
      final userName = userInfo['name'] as String? ?? displayName ?? userEmail;
      final userId = userInfo['id'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      final picture = userInfo['picture'] as String?;

      _currentUser = FirebridgeUser(
        id: userId,
        email: userEmail,
        displayName: userName,
        photoUrl: picture,
        accessToken: token,
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      );

      FirebridgeLogger.i('Direct token authenticated for: $userEmail', _tag);
      await _persistSession(_currentUser!);
      notifyListeners();
      return _currentUser!;
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> signOut() async {
    _setLoading(true);
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      await _storage.delete(key: _keyAuthUser);
      await _storage.delete(key: _keyAccessToken);
      _currentUser = null;
      FirebridgeLogger.i('Signed out and cleared credentials', _tag);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  @override
  Future<String> getValidAccessToken() async {
    if (_currentUser == null) {
      throw const FirebridgeException(
        code: FirebridgeErrorCodes.unauthenticated,
        message: 'No user is currently signed in to Firebridge.',
        resolutionSteps: 'Call Firebridge.auth.signIn() or signInWithToken() before accessing cloud resources.',
      );
    }

    if (_currentUser!.isTokenExpired) {
      FirebridgeLogger.i('Access token expired, attempting silent refresh...', _tag);
      try {
        final account = _googleSignIn.currentUser;
        if (account != null) {
          final auth = await account.authentication;
          if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
            _currentUser = _currentUser!.copyWith(
              accessToken: auth.accessToken!,
              idToken: auth.idToken,
              tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
            );
            await _persistSession(_currentUser!);
            return auth.accessToken!;
          }
        }
      } catch (e) {
        FirebridgeLogger.w('Silent token refresh failed: $e', _tag);
      }
    }

    return _currentUser!.accessToken;
  }

  Future<void> _persistSession(FirebridgeUser user) async {
    await _storage.write(key: _keyAuthUser, value: jsonEncode(user.toJson()));
    await _storage.write(key: _keyAccessToken, value: user.accessToken);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
