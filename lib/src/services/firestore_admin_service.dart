import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/logger.dart';

/// Information about a Cloud Firestore database instance.
class DatabaseInfo {
  /// Whether the database exists in the project.
  final bool exists;

  /// Operational state of the database (e.g. "READY", "INITIALIZING", "CREATING").
  final String? state;

  /// Regional or multi-regional location ID (e.g. "nam5", "us-central1").
  final String? locationId;

  /// Database type (e.g. "FIRESTORE_NATIVE").
  final String? type;

  const DatabaseInfo({
    required this.exists,
    this.state,
    this.locationId,
    this.type,
  });

  /// True when the database exists and its state is "READY".
  bool get isReady => exists && (state == 'READY' || state == null);

  @override
  String toString() =>
      'DatabaseInfo(exists: $exists, state: $state, location: $locationId, type: $type)';
}

/// Service interfacing with Cloud Firestore Admin v1 API.
class FirestoreAdminService {
  static const String _tag = 'FirestoreAdmin';

  final Future<String> Function() _getAccessToken;
  final http.Client _client;

  FirestoreAdminService(
    this._getAccessToken, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Checks whether a Firestore database exists and its operational state.
  Future<DatabaseInfo> checkDatabase(
    String projectId, {
    String databaseId = '(default)',
  }) async {
    final token = await _getAccessToken();
    FirebridgeLogger.i('Checking Firestore database "$databaseId" for $projectId...', _tag);

    final url = Uri.parse(FirebridgeConstants.firestoreDatabase(projectId, databaseId));
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
        final state = data['state'] as String? ?? 'READY';
        final locationId = data['locationId'] as String?;
        final type = data['type'] as String?;

        FirebridgeLogger.i('Firestore DB for $projectId exists (State: $state, Location: $locationId)', _tag);
        return DatabaseInfo(
          exists: true,
          state: state,
          locationId: locationId,
          type: type,
        );
      } else if (response.statusCode == 404) {
        // Fallback: check /databases collection in case default has alternative name
        try {
          final listUrl = Uri.parse(FirebridgeConstants.firestoreDatabases(projectId));
          final listRes = await _client.get(
            listUrl,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );
          if (listRes.statusCode == 200) {
            final listData = jsonDecode(listRes.body) as Map<String, dynamic>;
            final dbs = listData['databases'] as List<dynamic>? ?? [];
            if (dbs.isNotEmpty) {
              final first = dbs.first as Map<String, dynamic>;
              return DatabaseInfo(
                exists: true,
                state: first['state'] as String? ?? 'READY',
                locationId: first['locationId'] as String?,
                type: first['type'] as String?,
              );
            }
          }
        } catch (_) {}

        FirebridgeLogger.i('No Firestore database found for $projectId', _tag);
        return const DatabaseInfo(exists: false);
      }

      FirebridgeLogger.w('Checking database returned HTTP ${response.statusCode}: ${response.body}', _tag);
      return const DatabaseInfo(exists: false);
    } catch (e) {
      FirebridgeLogger.w('Error checking Firestore database: $e', _tag);
      return const DatabaseInfo(exists: false);
    }
  }

  /// Creates a Native Firestore database with backoff retry for Google Cloud propagation delays.
  Future<void> createDatabase({
    required String projectId,
    String databaseId = '(default)',
    String locationId = 'nam5',
    void Function(String message)? onProgress,
  }) async {
    // 1. Check if database already exists
    final initialCheck = await checkDatabase(projectId, databaseId: databaseId);
    if (initialCheck.exists) {
      FirebridgeLogger.i('Firestore database already active on $projectId', _tag);
      return;
    }

    final token = await _getAccessToken();
    FirebridgeLogger.i('Creating Firestore ($databaseId) in region $locationId on $projectId...', _tag);
    onProgress?.call('Initiating Firestore database in region $locationId...');

    final url = Uri.parse(
        '${FirebridgeConstants.firestoreDatabases(projectId)}?databaseId=$databaseId');

    // Retry loop with backoff for Google Cloud propagation latency
    http.Response? lastResponse;
    for (int attempt = 1; attempt <= 4; attempt++) {
      lastResponse = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'locationId': locationId,
          'type': 'FIRESTORE_NATIVE',
        }),
      );

      if (lastResponse.statusCode == 200 || lastResponse.statusCode == 202) {
        final data = jsonDecode(lastResponse.body) as Map<String, dynamic>;
        final opName = data['name'] as String?;
        if (opName != null && data['done'] != true) {
          onProgress?.call('Waiting for Firestore database provisioning...');
          await _pollOperation(opName, onProgress: onProgress);
        }
        FirebridgeLogger.i('Firestore database created successfully on $projectId', _tag);
        return;
      } else if (lastResponse.statusCode == 409) {
        FirebridgeLogger.i('Firestore database already exists on $projectId', _tag);
        return;
      } else if (lastResponse.statusCode == 404 && attempt < 4) {
        onProgress?.call(
            'Waiting for Google Cloud resource replication (attempt $attempt/4)...');
        await Future.delayed(const Duration(seconds: 4));
        final check = await checkDatabase(projectId, databaseId: databaseId);
        if (check.exists) return;
        continue;
      } else {
        break;
      }
    }

    final response = lastResponse!;
    throw FirebridgeException.fromResponse(
      response,
      customMessage:
          'Failed to create Cloud Firestore database on project "$projectId"',
    );
  }

  Future<void> _pollOperation(
    String operationName, {
    Duration timeout = const Duration(seconds: 60),
    void Function(String message)? onProgress,
  }) async {
    final token = await _getAccessToken();
    final url = Uri.parse('${FirebridgeConstants.firestoreBase}/$operationName');
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      await Future.delayed(const Duration(seconds: 3));

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
            final message =
                errorMap['message'] as String? ?? 'Firestore database creation failed';
            throw FirebridgeException(
              code: FirebridgeErrorCodes.firestoreCreateFailed,
              message: message,
              details: errorMap,
            );
          }
          return;
        }
        onProgress?.call('Provisioning Firestore database (${stopwatch.elapsed.inSeconds}s)...');
      }
    }
  }
}
