import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/logger.dart';

/// Service interfacing with Firebase Management v1beta1 API.
class FirebaseManagementService {
  static const String _tag = 'FirebaseManagement';

  final Future<String> Function() _getAccessToken;
  final http.Client _client;

  FirebaseManagementService(
    this._getAccessToken, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Lists all project IDs where Firebase is already enabled.
  Future<Set<String>> listFirebaseProjectIds() async {
    final token = await _getAccessToken();
    FirebridgeLogger.i('Listing Firebase-enabled projects...', _tag);

    final url = Uri.parse(FirebridgeConstants.firebaseProjects(pageSize: 100));
    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        final ids = results
            .map((p) => (p as Map<String, dynamic>)['projectId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        FirebridgeLogger.i('Found ${ids.length} projects with Firebase enabled', _tag);
        return ids;
      }

      FirebridgeLogger.w('Listing Firebase projects failed (${response.statusCode}): ${response.body}', _tag);
      return {};
    } catch (e) {
      FirebridgeLogger.w('Error querying Firebase projects: $e', _tag);
      return {};
    }
  }

  /// Checks if Firebase is enabled on a specific Google Cloud project.
  Future<bool> isFirebaseEnabled(String projectId) async {
    final token = await _getAccessToken();
    final url = Uri.parse(FirebridgeConstants.firebaseProject(projectId));

    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      FirebridgeLogger.w('Failed to check Firebase status for $projectId: $e', _tag);
      return false;
    }
  }

  /// Enables Firebase on an existing Google Cloud project.
  Future<void> addFirebase(
    String projectId, {
    void Function(String message)? onProgress,
  }) async {
    final token = await _getAccessToken();
    FirebridgeLogger.i('Adding Firebase to project $projectId...', _tag);
    onProgress?.call('Associating Firebase with project...');

    final url = Uri.parse(FirebridgeConstants.firebaseAdd(projectId));
    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200 || response.statusCode == 202) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final opName = data['name'] as String?;
      if (opName != null && data['done'] != true) {
        await _pollOperation(opName, onProgress: onProgress);
      }
      FirebridgeLogger.i('Firebase successfully added to $projectId', _tag);
      return;
    } else if (response.statusCode == 409) {
      FirebridgeLogger.i('Firebase is already added to $projectId', _tag);
      return;
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to add Firebase to project "$projectId"',
    );
  }

  Future<void> _pollOperation(
    String operationName, {
    Duration timeout = const Duration(seconds: 45),
    void Function(String message)? onProgress,
  }) async {
    final token = await _getAccessToken();
    final url = Uri.parse(FirebridgeConstants.firebaseOperation(operationName));
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      await Future.delayed(const Duration(seconds: 2));

      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['done'] == true) {
          if (data['error'] != null) {
            final errorMap = data['error'] as Map<String, dynamic>;
            final message = errorMap['message'] as String? ?? 'Firebase addition failed';
            throw FirebridgeException(
              code: FirebridgeErrorCodes.cloudPermissionDenied,
              message: message,
              details: errorMap,
            );
          }
          return;
        }
        onProgress?.call('Enabling Firebase (${stopwatch.elapsed.inSeconds}s)...');
      }
    }
  }
}
