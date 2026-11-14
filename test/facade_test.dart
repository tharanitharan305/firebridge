import 'package:flutter_test/flutter_test.dart';
import 'package:firebridge_flutter/firebridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firebridge Facade Tests', () {
    test('Uninitialized access throws descriptive FirebridgeException', () {
      expect(Firebridge.isInitialized, isFalse);
      expect(
        () => Firebridge.auth,
        throwsA(isA<FirebridgeException>().having(
          (e) => e.code,
          'code',
          FirebridgeErrorCodes.unauthenticated,
        )),
      );
      expect(
        () => Firebridge.projects,
        throwsA(isA<FirebridgeException>().having(
          (e) => e.code,
          'code',
          FirebridgeErrorCodes.unauthenticated,
        )),
      );
      expect(
        () => Firebridge.use('test-proj'),
        throwsA(isA<FirebridgeException>().having(
          (e) => e.code,
          'code',
          FirebridgeErrorCodes.unauthenticated,
        )),
      );
    });

    test('Firebridge.initialize() sets up config and services', () async {
      await Firebridge.initialize(
        enableLogging: true,
        webClientId: 'my-web-client-id.apps.googleusercontent.com',
        defaultRegion: 'europe-west1',
      );

      expect(Firebridge.isInitialized, isTrue);
      expect(Firebridge.config.enableLogging, isTrue);
      expect(Firebridge.config.webClientId, 'my-web-client-id.apps.googleusercontent.com');
      expect(Firebridge.config.defaultRegion, 'europe-west1');
      expect(FirebridgeLogger.enabled, isTrue);

      final app = Firebridge.use('my-custom-project');
      expect(app.projectId, 'my-custom-project');
      expect(app.databaseId, '(default)');
      expect(app.firestore, isNotNull);
    });
  });
}
