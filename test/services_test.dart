import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebridge_flutter/src/core/config.dart';
import 'package:firebridge_flutter/src/services/crm_service.dart';
import 'package:firebridge_flutter/src/services/service_usage_service.dart';
import 'package:firebridge_flutter/src/services/firebase_mgmt_service.dart';
import 'package:firebridge_flutter/src/services/firestore_admin_service.dart';
import 'package:firebridge_flutter/src/services/auth_service.dart';

void main() {
  const config = FirebridgeConfig(enableLogging: false);
  Future<String> getMockToken() async => 'mock-oauth-token-123';

  group('CRM Service Tests', () {
    test('listProjects maps active projects correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer mock-oauth-token-123');
        return http.Response(
          jsonEncode({
            'projects': [
              {
                'projectId': 'project-active-1',
                'projectNumber': '1001',
                'name': 'Active Project',
                'lifecycleState': 'ACTIVE',
              },
              {
                'projectId': 'project-deleted-2',
                'projectNumber': '1002',
                'name': 'Deleted Project',
                'lifecycleState': 'DELETE_REQUESTED',
              },
            ]
          }),
          200,
        );
      });

      final crm = CloudResourceManagerService(getMockToken, client: mockClient);
      final projects = await crm.listProjects();

      expect(projects.length, 1);
      expect(projects.first.projectId, 'project-active-1');
      expect(projects.first.lifecycleState, 'ACTIVE');
    });

    test('createProject returns operation name or done', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['projectId'], 'new-byof-project');
        return http.Response(
          jsonEncode({'name': 'operations/cp.12345'}),
          200,
        );
      });

      final crm = CloudResourceManagerService(getMockToken, client: mockClient);
      final op = await crm.createProject(
        projectId: 'new-byof-project',
        projectName: 'New BYOF Project',
      );

      expect(op, 'operations/cp.12345');
    });
  });

  group('Service Usage Service Tests', () {
    test('isServiceEnabled detects ENABLED state', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'state': 'ENABLED'}), 200);
      });

      final su = ServiceUsageService(getMockToken, client: mockClient);
      final isEnabled = await su.isServiceEnabled('p-1', 'firestore.googleapis.com');
      expect(isEnabled, isTrue);
    });

    test('isServiceEnabled detects DISABLED state', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'state': 'DISABLED'}), 200);
      });

      final su = ServiceUsageService(getMockToken, client: mockClient);
      final isEnabled = await su.isServiceEnabled('p-1', 'firestore.googleapis.com');
      expect(isEnabled, isFalse);
    });
  });

  group('Firebase Management Service Tests', () {
    test('listFirebaseProjectIds extracts set of IDs', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {'projectId': 'firebase-app-1'},
              {'projectId': 'firebase-app-2'},
            ]
          }),
          200,
        );
      });

      final fbm = FirebaseManagementService(getMockToken, client: mockClient);
      final ids = await fbm.listFirebaseProjectIds();

      expect(ids.length, 2);
      expect(ids.contains('firebase-app-1'), isTrue);
      expect(ids.contains('firebase-app-2'), isTrue);
    });
  });

  group('Firestore Admin Service Tests', () {
    test('checkDatabase returns isReady true when state is READY', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'state': 'READY',
            'locationId': 'nam5',
            'type': 'FIRESTORE_NATIVE',
          }),
          200,
        );
      });

      final admin = FirestoreAdminService(getMockToken, client: mockClient);
      final info = await admin.checkDatabase('proj-1');

      expect(info.exists, isTrue);
      expect(info.isReady, isTrue);
      expect(info.locationId, 'nam5');
    });

    test('checkDatabase returns exists false on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Not found"}', 404);
      });

      final admin = FirestoreAdminService(getMockToken, client: mockClient);
      final info = await admin.checkDatabase('proj-1');

      expect(info.exists, isFalse);
      expect(info.isReady, isFalse);
    });
  });

  group('Direct Token Auth Tests', () {
    test('FirebridgeAuthServiceImpl initializes with unauthenticated state', () async {
      final auth = FirebridgeAuthServiceImpl(config: config);
      expect(auth.isSignedIn, isFalse);
      expect(auth.currentUser, isNull);
    });
  });
}
