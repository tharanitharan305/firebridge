import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebridge/src/core/errors.dart';
import 'package:firebridge/src/services/crm_service.dart';
import 'package:firebridge/src/services/service_usage_service.dart';
import 'package:firebridge/src/services/firebase_mgmt_service.dart';
import 'package:firebridge/src/services/firestore_admin_service.dart';
import 'package:firebridge/src/services/provisioning_engine.dart';

void main() {
  Future<String> getMockToken() async => 'mock-token';

  group('Project ID Validation & Generation', () {
    test('isValidProjectId correctly validates GCP constraints', () {
      // Valid project IDs (6-30 chars, lowercase alphanumeric + hyphen, start with letter, no trailing hyphen)
      expect(FirebridgeProvisioningEngine.isValidProjectId('fb-byof-123456'), isTrue);
      expect(FirebridgeProvisioningEngine.isValidProjectId('my-app-db'), isTrue);
      expect(FirebridgeProvisioningEngine.isValidProjectId('project123'), isTrue);
      expect(FirebridgeProvisioningEngine.isValidProjectId('a12345'), isTrue);

      // Invalid IDs
      expect(FirebridgeProvisioningEngine.isValidProjectId('123abc'), isFalse); // starts with digit
      expect(FirebridgeProvisioningEngine.isValidProjectId('short'), isFalse); // < 6 chars
      expect(FirebridgeProvisioningEngine.isValidProjectId('trailing-hyphen-'), isFalse); // ends with hyphen
      expect(FirebridgeProvisioningEngine.isValidProjectId('CapitalLetters'), isFalse); // uppercase
      expect(FirebridgeProvisioningEngine.isValidProjectId('a-very-long-project-id-that-exceeds-thirty-characters-limit'), isFalse); // > 30
      expect(FirebridgeProvisioningEngine.isValidProjectId('under_score'), isFalse); // underscore not allowed
    });

    test('generateUniqueProjectId produces compliant GCP project IDs', () {
      for (int i = 0; i < 20; i++) {
        final id = FirebridgeProvisioningEngine.generateUniqueProjectId();
        expect(FirebridgeProvisioningEngine.isValidProjectId(id), isTrue,
            reason: 'Generated ID "$id" failed GCP validation');
      }
    });
  });

  group('Provisioning Engine Pipeline', () {
    test('Orchestrates full 6-step pipeline successfully and emits progress', () async {
      final progressLog = <ProvisioningStep>[];

      final mockClient = MockClient((request) async {
        final uri = request.url.toString();

        // Step 2: CRM Project Creation
        if (uri.contains('/v1/projects') && request.method == 'POST') {
          return http.Response(jsonEncode({'name': null}), 200); // synchronous success
        }

        // Step 3: Service Usage (check and enable)
        if (uri.contains('/services/') && uri.endsWith(':enable')) {
          return http.Response(jsonEncode({'done': true}), 200);
        }
        if (uri.contains('/services/')) {
          return http.Response(jsonEncode({'state': 'ENABLED'}), 200);
        }

        // Step 4: Firebase Add
        if (uri.contains(':addFirebase')) {
          return http.Response(jsonEncode({'done': true}), 200);
        }

        // Step 5 & 6: Firestore Database
        if (uri.contains('/databases')) {
          return http.Response(
            jsonEncode({
              'state': 'READY',
              'locationId': 'nam5',
              'type': 'FIRESTORE_NATIVE',
            }),
            200,
          );
        }

        return http.Response('{}', 200);
      });

      final crm = CloudResourceManagerService(getMockToken, client: mockClient);
      final su = ServiceUsageService(getMockToken, client: mockClient);
      final fbm = FirebaseManagementService(getMockToken, client: mockClient);
      final fsa = FirestoreAdminService(getMockToken, client: mockClient);

      final engine = FirebridgeProvisioningEngine(
        crmService: crm,
        serviceUsageService: su,
        firebaseService: fbm,
        firestoreAdminService: fsa,
      );

      final project = await engine.provision(
        projectId: 'test-pipe-12345',
        projectName: 'Pipeline Test Project',
        onProgress: (p) => progressLog.add(p.step),
      );

      expect(project.projectId, 'test-pipe-12345');
      expect(project.name, 'Pipeline Test Project');
      expect(project.isReady, isTrue);
      expect(project.isFirebaseEnabled, isTrue);
      expect(project.isFirestoreActive, isTrue);

      // Verify that progress steps were triggered
      expect(progressLog.contains(ProvisioningStep.generatingId), isTrue);
      expect(progressLog.contains(ProvisioningStep.creatingProject), isTrue);
      expect(progressLog.contains(ProvisioningStep.enablingApis), isTrue);
      expect(progressLog.contains(ProvisioningStep.addingFirebase), isTrue);
      expect(progressLog.contains(ProvisioningStep.creatingFirestore), isTrue);
      expect(progressLog.contains(ProvisioningStep.completed), isTrue);
    });

    test('Translates Quota Exceeded error correctly and halts pipeline', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('/v1/projects') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 403,
                'status': 'PERMISSION_DENIED',
                'message': 'Project creation quota exceeded for your account.',
              }
            }),
            403,
          );
        }
        return http.Response('{}', 200);
      });

      final crm = CloudResourceManagerService(getMockToken, client: mockClient);
      final su = ServiceUsageService(getMockToken, client: mockClient);
      final fbm = FirebaseManagementService(getMockToken, client: mockClient);
      final fsa = FirestoreAdminService(getMockToken, client: mockClient);

      final engine = FirebridgeProvisioningEngine(
        crmService: crm,
        serviceUsageService: su,
        firebaseService: fbm,
        firestoreAdminService: fsa,
      );

      expect(
        () => engine.provision(projectId: 'quota-test-999'),
        throwsA(isA<FirebridgeQuotaException>()),
      );
    });
  });
}

