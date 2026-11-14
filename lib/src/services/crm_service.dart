import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/logger.dart';
import '../models/project.dart';

/// Service interfacing with Google Cloud Resource Manager v1 API.
class CloudResourceManagerService {
  static const String _tag = 'CloudResourceManager';

  final Future<String> Function() _getAccessToken;
  final http.Client _client;

  CloudResourceManagerService(
    this._getAccessToken, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Lists Google Cloud projects accessible by the authenticated user.
  Future<List<FirebridgeProject>> listProjects() async {
    final token = await _getAccessToken();
    FirebridgeLogger.i('Fetching Google Cloud projects...', _tag);

    final url = Uri.parse(FirebridgeConstants.crmProjects(pageSize: 100));
    final response = await _client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['projects'] as List<dynamic>? ?? [];
      FirebridgeLogger.i('Found ${list.length} Cloud projects', _tag);

      return list
          .map((p) => FirebridgeProject.fromJson(p as Map<String, dynamic>))
          .where((p) => p.lifecycleState == 'ACTIVE')
          .toList();
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to retrieve Google Cloud projects',
    );
  }

  /// Creates a new Google Cloud project under the authenticated user's account.
  Future<String> createProject({
    required String projectId,
    required String projectName,
  }) async {
    final token = await _getAccessToken();
    FirebridgeLogger.i('Creating new Cloud project "$projectName" ($projectId)...', _tag);

    final url = Uri.parse('${FirebridgeConstants.crmBase}/projects');
    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'projectId': projectId,
        'name': projectName,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 202) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final opName = data['name'] as String?;
      if (opName == null) {
        FirebridgeLogger.i('Project $projectId created synchronously', _tag);
        return 'done';
      }
      FirebridgeLogger.i('Project creation operation started: $opName', _tag);
      return opName;
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to create Google Cloud project "$projectId"',
    );
  }

  /// Polls a long-running Cloud Resource Manager operation until complete.
  Future<void> pollOperation(
    String operationName, {
    Duration timeout = const Duration(seconds: 45),
    void Function(String message)? onProgress,
  }) async {
    final token = await _getAccessToken();
    final url = Uri.parse(FirebridgeConstants.crmOperation(operationName));
    final stopwatch = Stopwatch()..start();

    FirebridgeLogger.i('Polling CRM operation: $operationName...', _tag);

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
            final message = errorMap['message'] as String? ?? 'CRM operation failed';
            throw FirebridgeException(
              code: FirebridgeErrorCodes.cloudPermissionDenied,
              message: message,
              details: errorMap,
            );
          }
          FirebridgeLogger.i('CRM operation completed successfully in ${stopwatch.elapsed.inSeconds}s', _tag);
          return;
        }
        onProgress?.call('Creating project (${stopwatch.elapsed.inSeconds}s)...');
      } else {
        FirebridgeLogger.w('CRM operation poll HTTP ${response.statusCode}: ${response.body}', _tag);
      }
    }

    FirebridgeLogger.w('CRM operation poll timed out after ${timeout.inSeconds}s, continuing...', _tag);
  }
}
