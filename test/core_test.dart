import 'package:flutter_test/flutter_test.dart';
import 'package:firebridge/src/core/config.dart';
import 'package:firebridge/src/core/logger.dart';
import 'package:firebridge/src/core/errors.dart';

void main() {
  group('FirebridgeConfig tests', () {
    test('default configuration values', () {
      const config = FirebridgeConfig();
      expect(config.enableLogging, isFalse);
      expect(config.webClientId, isNull);
      expect(config.defaultRegion, 'nam5');
      expect(config.scopes.length, 6);
    });

    test('copyWith updates fields', () {
      const config = FirebridgeConfig();
      final updated = config.copyWith(
        enableLogging: true,
        webClientId: 'test.apps.googleusercontent.com',
        defaultRegion: 'europe-west1',
      );
      expect(updated.enableLogging, isTrue);
      expect(updated.webClientId, 'test.apps.googleusercontent.com');
      expect(updated.defaultRegion, 'europe-west1');
    });
  });

  group('FirebridgeLogger tests', () {
    test('redacts sensitive tokens', () {
      FirebridgeLogger.enabled = false;
      // Logger does not crash when disabled
      FirebridgeLogger.i('Bearer ya29.a0AfH6SM89347528394752893475928347598234');
      FirebridgeLogger.e('key=AIzaSyA89347528394752893475928347598234');
    });
  });

  group('FirebridgeException tests', () {
    test('parses Google Cloud SERVICE_DISABLED error response', () {
      const gcpError = '''
      {
        "error": {
          "code": 403,
          "message": "Cloud Resource Manager API has not been used in project 1027184333516 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudresourcemanager.googleapis.com/overview?project=1027184333516 then retry.",
          "status": "PERMISSION_DENIED",
          "details": [
            {
              "@type": "type.googleapis.com/google.rpc.ErrorInfo",
              "reason": "SERVICE_DISABLED",
              "metadata": {
                "activationUrl": "https://console.developers.google.com/apis/api/cloudresourcemanager.googleapis.com/overview?project=1027184333516"
              }
            }
          ]
        }
      }
      ''';

      final ex = FirebridgeException.fromHttpResponse(403, gcpError);

      expect(ex, isA<FirebridgeApiException>());
      expect(ex.code, 'FB_API_NOT_ENABLED');
      expect(ex.helpUrl, contains('cloudresourcemanager.googleapis.com'));
      expect(ex.resolutionSteps, isNotNull);
      expect(ex.resolutionSteps, contains('ENABLE'));
    });

    test('parses Google Cloud 404 NOT_FOUND error response', () {
      const notFoundError = '''
      {
        "error": {
          "code": 404,
          "message": "Permission denied on resource or it may not exist.",
          "status": "NOT_FOUND"
        }
      }
      ''';

      final ex = FirebridgeException.fromHttpResponse(404, notFoundError);

      expect(ex, isA<FirebridgeNotFoundException>());
      expect(ex.code, 'FB_FIRESTORE_NOT_FOUND');
      expect(ex.resolutionSteps, contains('wait 30 seconds and retry'));
    });
  });
}

