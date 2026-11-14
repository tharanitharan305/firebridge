import 'dart:async';
import 'package:flutter/widgets.dart';

import 'src/core/config.dart';
import 'src/core/constants.dart';
import 'src/core/errors.dart';
import 'src/core/logger.dart';
import 'src/services/auth_service.dart';
import 'src/services/crm_service.dart';
import 'src/services/firebase_mgmt_service.dart';
import 'src/services/firestore_admin_service.dart';
import 'src/services/firestore_client.dart';
import 'src/services/project_service.dart';
import 'src/services/provisioning_engine.dart';
import 'src/services/service_usage_service.dart';

// --- Public Exports ---
export 'src/core/config.dart';
export 'src/core/constants.dart';
export 'src/core/errors.dart';
export 'src/core/logger.dart';
export 'src/models/document.dart';
export 'src/models/project.dart';
export 'src/models/user.dart';
export 'src/services/auth_service.dart';
export 'src/services/firestore_client.dart';
export 'src/services/project_service.dart';
export 'src/services/provisioning_engine.dart';
export 'src/ui/error_dialog.dart';
export 'src/ui/project_picker.dart';

/// Top-level facade for configuring and interacting with Firebridge BYOC infrastructure.
class Firebridge {
  Firebridge._();

  static FirebridgeConfig _config = const FirebridgeConfig();
  static FirebridgeAuthServiceImpl? _auth;
  static FirebridgeProjectServiceImpl? _projects;

  /// Global package configuration.
  static FirebridgeConfig get config => _config;

  /// Authentication service for Google Sign-In and direct token sessions.
  static FirebridgeAuthService get auth {
    _ensureInitialized();
    return _auth!;
  }

  /// Project management service for listing, inspecting, and provisioning GCP/Firebase projects.
  static FirebridgeProjectService get projects {
    _ensureInitialized();
    return _projects!;
  }

  /// True if `Firebridge.initialize()` has completed.
  static bool get isInitialized => _auth != null;

  /// Initializes the Firebridge engine with runtime configuration.
  ///
  /// - [enableLogging]: set to `true` to view detailed, credential-redacted HTTP & provisioning logs.
  /// - [webClientId]: required for Web platform OAuth 2.0 authentication.
  /// - [defaultRegion]: regional or multi-regional location ID for Firestore (defaults to 'nam5').
  /// - [additionalScopes]: additional OAuth 2.0 scopes if needed.
  static Future<void> initialize({
    bool enableLogging = false,
    String? webClientId,
    String defaultRegion = 'nam5',
    List<String>? additionalScopes,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final combinedScopes = [
      ...FirebridgeConstants.defaultScopes,
      ...?additionalScopes,
    ];

    _config = FirebridgeConfig(
      enableLogging: enableLogging,
      webClientId: webClientId,
      defaultRegion: defaultRegion,
      scopes: combinedScopes,
    );

    // Apply logging gate
    FirebridgeLogger.enabled = enableLogging;

    // Instantiate Auth Service
    final authService = FirebridgeAuthServiceImpl(config: _config);
    _auth = authService;

    // Token provider closure
    Future<String> tokenProvider() => authService.getValidAccessToken();

    // Instantiate Sub-Services
    final crmService = CloudResourceManagerService(tokenProvider);
    final serviceUsageService = ServiceUsageService(tokenProvider);
    final firebaseService = FirebaseManagementService(tokenProvider);
    final firestoreAdminService = FirestoreAdminService(tokenProvider);

    final provisioningEngine = FirebridgeProvisioningEngine(
      crmService: crmService,
      serviceUsageService: serviceUsageService,
      firebaseService: firebaseService,
      firestoreAdminService: firestoreAdminService,
    );

    _projects = FirebridgeProjectServiceImpl(
      crmService: crmService,
      firebaseService: firebaseService,
      firestoreAdminService: firestoreAdminService,
      provisioningEngine: provisioningEngine,
    );

    // Attempt restoring existing session
    try {
      await authService.restoreSession();
    } catch (e) {
      FirebridgeLogger.w('Initial session restore skipped: $e', 'Firebridge');
    }

    FirebridgeLogger.i('Firebridge initialized successfully (logging: $enableLogging)', 'Firebridge');
  }

  /// Binds to a specific Google Cloud project and returns a [FirebridgeApp]
  /// providing access to Cloud Firestore REST collections and documents.
  ///
  /// ```dart
  /// final app = Firebridge.use('my-byof-project-12345');
  /// final notes = await app.firestore.collection('notes').get();
  /// ```
  static FirebridgeApp use(String projectId, {String databaseId = '(default)'}) {
    _ensureInitialized();
    return FirebridgeApp(
      projectId: projectId,
      databaseId: databaseId,
      getAccessToken: () => _auth!.getValidAccessToken(),
    );
  }

  static void _ensureInitialized() {
    if (_auth == null) {
      throw const FirebridgeException(
        code: FirebridgeErrorCodes.unauthenticated,
        message:
            'Firebridge is not initialized. Call await Firebridge.initialize() in your main() function before accessing services.',
        resolutionSteps:
            '1. Call `await Firebridge.initialize(...)` inside your `void main() async` function before runApp().',
      );
    }
  }
}
