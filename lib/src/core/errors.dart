import 'dart:convert';
import 'package:http/http.dart' as http;

/// Catalog of standard error codes for Firebridge.
class FirebridgeErrorCodes {
  static const String unauthenticated = 'FB_UNAUTHENTICATED';
  static const String authFailed = 'FB_AUTH_FAILED';
  static const String authCancelled = 'FB_AUTH_CANCELLED';
  static const String authTokenExpired = 'FB_AUTH_TOKEN_EXPIRED';
  static const String webClientIdMissing = 'FB_WEB_CLIENT_ID_MISSING';
  static const String apiNotEnabled = 'FB_API_NOT_ENABLED';
  static const String cloudPermissionDenied = 'FB_PERMISSION_DENIED';
  static const String quotaExceeded = 'FB_QUOTA_EXCEEDED';
  static const String billingRequired = 'FB_BILLING_REQUIRED';
  static const String firestoreNotFound = 'FB_FIRESTORE_NOT_FOUND';
  static const String firestoreCreateFailed = 'FB_FIRESTORE_CREATE_FAILED';
  static const String projectCollision = 'FB_PROJECT_COLLISION';
  static const String propagationTimeout = 'FB_PROPAGATION_TIMEOUT';
  static const String networkError = 'FB_NETWORK_ERROR';
}

/// Base exception for all errors thrown by the Firebridge BYOC package.
class FirebridgeException implements Exception {
  /// Machine-readable unique error code (e.g. `FB_API_NOT_ENABLED`).
  final String code;

  /// Human-readable explanation of what went wrong.
  final String message;

  /// Actionable step-by-step instructions for the developer or user to resolve the error.
  final String? resolutionSteps;

  /// Direct link to the relevant Google Cloud Console or Firebase Console settings page.
  final String? helpUrl;

  /// Raw underlying exception, status code, or server response payload.
  final dynamic details;

  const FirebridgeException({
    required this.code,
    required this.message,
    this.resolutionSteps,
    this.helpUrl,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('FirebridgeException [$code]: $message');
    if (resolutionSteps != null) {
      buffer.write('\nResolution Steps:\n$resolutionSteps');
    }
    if (helpUrl != null) {
      buffer.write('\nHelp URL: $helpUrl');
    }
    return buffer.toString();
  }

  /// Convenience factory creating [FirebridgeException] from an [http.Response].
  factory FirebridgeException.fromResponse(
    http.Response response, {
    String? customMessage,
  }) =>
      FirebridgeException.fromHttpResponse(
        response.statusCode,
        response.body,
        contextMessage: customMessage,
      );

  /// Parses a Google Cloud REST JSON error response into a typed FirebridgeException.
  factory FirebridgeException.fromHttpResponse(
    int statusCode,
    String responseBody, {
    String? contextMessage,
  }) {
    String message = contextMessage ?? 'Google Cloud API request failed ($statusCode)';
    String code = 'FB_API_ERROR_$statusCode';
    String? resolutionSteps;
    String? helpUrl;
    dynamic parsedDetails = responseBody;

    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      parsedDetails = json;
      if (json['error'] is Map) {
        final err = json['error'] as Map<String, dynamic>;
        final serverMessage = err['message'] as String? ?? '';
        final status = err['status'] as String? ?? '';

        if (serverMessage.isNotEmpty) {
          message = contextMessage != null
              ? '$contextMessage: $serverMessage'
              : serverMessage;
        }

        // Parse details array if present
        final detailsList = err['details'] as List<dynamic>? ?? [];
        for (final item in detailsList) {
          if (item is Map<String, dynamic>) {
            // Check for Help links
            final links = item['links'] as List<dynamic>?;
            if (links != null && links.isNotEmpty) {
              final firstLink = links.first as Map<String, dynamic>;
              helpUrl = firstLink['url'] as String?;
            }

            // Check for ErrorInfo metadata
            final metadata = item['metadata'] as Map<String, dynamic>?;
            if (metadata != null) {
              if (metadata['activationUrl'] != null) {
                helpUrl = metadata['activationUrl'] as String;
              }
              final service = metadata['service'] as String?;
              final consumer = metadata['consumer'] as String?;
              if (service != null && consumer != null) {
                resolutionSteps =
                    '1. Enable the "$service" API for project "$consumer".\n'
                    '2. Open the activation link: ${helpUrl ?? "https://console.cloud.google.com/apis/library/$service"}\n'
                    '3. Click the blue "ENABLE" button and wait 30 seconds for replication.';
              }
            }
          }
        }

        // 1. Service / API Disabled (403 PERMISSION_DENIED with SERVICE_DISABLED)
        final reason = detailsList.firstWhere(
          (d) => d is Map && d['reason'] == 'SERVICE_DISABLED',
          orElse: () => null,
        );
        if (reason != null || serverMessage.contains('has not been used in project')) {
          code = FirebridgeErrorCodes.apiNotEnabled;
          resolutionSteps ??=
              '1. Click the help link to open Google Cloud Console.\n'
              '2. Click the blue "ENABLE" button.\n'
              '3. Wait 30 seconds for changes to replicate.';
          return FirebridgeApiException(
            code: code,
            message: message,
            resolutionSteps: resolutionSteps,
            helpUrl: helpUrl,
            details: parsedDetails,
          );
        }

        // 2. Permission Denied / Billing
        if (statusCode == 403 || status == 'PERMISSION_DENIED') {
          if (serverMessage.toLowerCase().contains('quota')) {
            code = FirebridgeErrorCodes.quotaExceeded;
            helpUrl = 'https://console.cloud.google.com/iam-admin/quotas';
            resolutionSteps =
                '1. Your Google Cloud project creation quota has been reached.\n'
                '2. Request a quota increase or select an existing active project.';
            return FirebridgeQuotaException(
              code: code,
              message: message,
              resolutionSteps: resolutionSteps,
              helpUrl: helpUrl,
              details: parsedDetails,
            );
          }

          if (serverMessage.toLowerCase().contains('billing')) {
            code = FirebridgeErrorCodes.billingRequired;
            helpUrl = 'https://console.cloud.google.com/billing';
            resolutionSteps =
                '1. This project requires an active billing account linked in Google Cloud Console.\n'
                '2. Open the billing URL and link a payment method.';
            return FirebridgeBillingException(
              code: code,
              message: message,
              resolutionSteps: resolutionSteps,
              helpUrl: helpUrl,
              details: parsedDetails,
            );
          }

          code = FirebridgeErrorCodes.cloudPermissionDenied;
          helpUrl = 'https://console.cloud.google.com/iam-admin/iam';
          resolutionSteps =
              '1. Verify that your Google account has Owner or Editor role on this project.\n'
              '2. If you do not have permission, create a new project where you are the Owner.';
          return FirebridgePermissionException(
            code: code,
            message: message,
            resolutionSteps: resolutionSteps,
            helpUrl: helpUrl,
            details: parsedDetails,
          );
        }

        // 3. Not Found (404)
        if (statusCode == 404 || status == 'NOT_FOUND') {
          code = FirebridgeErrorCodes.firestoreNotFound;
          resolutionSteps =
              '1. The requested project or Firestore database was not found or permissions are propagating.\n'
              '2. If you recently enabled Firestore, wait 30 seconds and retry.\n'
              '3. Ensure Firestore is in Native mode.';
          return FirebridgeNotFoundException(
            code: code,
            message: message,
            resolutionSteps: resolutionSteps,
            helpUrl: helpUrl,
            details: parsedDetails,
          );
        }

        // 4. Collision / Conflict (409)
        if (statusCode == 409 || status == 'ALREADY_EXISTS') {
          code = FirebridgeErrorCodes.projectCollision;
          resolutionSteps = 'The project ID or resource name already exists globally. Provide a unique ID.';
          return FirebridgeProvisioningException(
            code: code,
            message: message,
            resolutionSteps: resolutionSteps,
            details: parsedDetails,
          );
        }
      }
    } catch (_) {}

    return FirebridgeException(
      code: code,
      message: message,
      resolutionSteps: resolutionSteps,
      helpUrl: helpUrl,
      details: parsedDetails,
    );
  }
}

class FirebridgeAuthException extends FirebridgeException {
  const FirebridgeAuthException({
    required super.code,
    required super.message,
    super.resolutionSteps,
    super.helpUrl,
    super.details,
  });
}

class FirebridgeApiException extends FirebridgeException {
  const FirebridgeApiException({
    required super.code,
    required super.message,
    super.resolutionSteps,
    super.helpUrl,
    super.details,
  });
}

class FirebridgePermissionException extends FirebridgeException {
  const FirebridgePermissionException({
    required super.code,
    required super.message,
    super.resolutionSteps,
    super.helpUrl,
    super.details,
  });
}

class FirebridgeQuotaException extends FirebridgeException {
  const FirebridgeQuotaException({
    required super.code,
    required super.message,
    super.resolutionSteps,
    super.helpUrl,
    super.details,
  });
}

class FirebridgeBillingException extends FirebridgeException {
  const FirebridgeBillingException({
    required super.code,
    required super.message,
    super.resolutionSteps,
    super.helpUrl,
    super.details,
  });
}

class FirebridgeNotFoundException extends FirebridgeException {
  const FirebridgeNotFoundException({
    required super.code,
    required super.message,
    super.resolutionSteps,
    super.helpUrl,
    super.details,
  });
}

class FirebridgeProvisioningException extends FirebridgeException {
  const FirebridgeProvisioningException({
    required super.code,
    required super.message,
    super.resolutionSteps,
    super.helpUrl,
    super.details,
  });
}
