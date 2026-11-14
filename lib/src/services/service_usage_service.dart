import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/logger.dart';

/// Service interfacing with Google Cloud Service Usage v1 API to enable required APIs.
class ServiceUsageService {
  static const String _tag = 'ServiceUsage';

  final Future<String> Function() _getAccessToken;
  final http.Client _client;

  ServiceUsageService(
    this._getAccessToken, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Checks if a specific service is enabled on the project.
  Future<bool> isServiceEnabled(String projectId, String serviceId) async {
    final token = await _getAccessToken();
    final url = Uri.parse(FirebridgeConstants.serviceUsageGet(projectId, serviceId));

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
        return data['state'] == 'ENABLED';
      }
      return false;
    } catch (e) {
      FirebridgeLogger.w('Failed to check service $serviceId: $e', _tag);
      return false;
    }
  }

  /// Enables a specific Google Cloud API service on the target project.
  Future<void> enableService(String projectId, String serviceId) async {
    final token = await _getAccessToken();
    FirebridgeLogger.i('Enabling API "$serviceId" on $projectId...', _tag);

    final url = Uri.parse(FirebridgeConstants.serviceUsageEnable(projectId, serviceId));
    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 202) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final opName = data['name'] as String?;
      if (opName != null && data['done'] != true) {
        await _pollOperation(opName);
      }
      FirebridgeLogger.i('API $serviceId enabled successfully', _tag);
      return;
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to enable API $serviceId',
    );
  }

  /// Enables all required Firebridge services (Service Usage, Firestore, Datastore, Firebase).
  Future<void> enableAllRequiredServices(
    String projectId, {
    void Function(String message)? onProgress,
  }) async {
    bool newlyEnabled = false;

    for (final service in FirebridgeConstants.requiredServices) {
      final alreadyEnabled = await isServiceEnabled(projectId, service);
      if (alreadyEnabled) {
        onProgress?.call('$service already enabled');
        continue;
      }

      onProgress?.call('Enabling $service...');
      await enableService(projectId, service);
      newlyEnabled = true;
    }

    if (newlyEnabled) {
      onProgress?.call('Waiting for Google Cloud service replication (4s)...');
      FirebridgeLogger.i('Waiting 4s for GCP API enablement internal replication...', _tag);
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<void> _pollOperation(
    String operationName, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final token = await _getAccessToken();
    final url = Uri.parse(FirebridgeConstants.serviceUsageOperation(operationName));
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
            final message = errorMap['message'] as String? ?? 'Service enablement failed';
            throw FirebridgeException(
              code: FirebridgeErrorCodes.cloudPermissionDenied,
              message: message,
              details: errorMap,
            );
          }
          return;
        }
      }
    }
  }
}
