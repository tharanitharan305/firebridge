import 'package:flutter_test/flutter_test.dart';
import 'package:firebridge/src/models/user.dart';
import 'package:firebridge/src/models/project.dart';
import 'package:firebridge/src/models/document.dart';

void main() {
  group('FirebridgeUser Tests', () {
    test('Token expiry calculations correctly account for 60s buffer', () {
      final now = DateTime.now();

      // Expired 5 seconds ago
      final userExpired = FirebridgeUser(
        id: 'u-1',
        email: 'test@example.com',
        displayName: 'Test User',
        accessToken: 'token-abc',
        tokenExpiry: now.subtract(const Duration(seconds: 5)),
      );
      expect(userExpired.isTokenExpired, isTrue);

      // Expires in 30 seconds (less than 60s buffer -> considered expired)
      final userExpiringSoon = FirebridgeUser(
        id: 'u-2',
        email: 'test@example.com',
        displayName: 'Test User',
        accessToken: 'token-abc',
        tokenExpiry: now.add(const Duration(seconds: 30)),
      );
      expect(userExpiringSoon.isTokenExpired, isTrue);

      // Expires in 5 minutes -> not expired
      final userValid = FirebridgeUser(
        id: 'u-3',
        email: 'test@example.com',
        displayName: 'Test User',
        accessToken: 'token-abc',
        tokenExpiry: now.add(const Duration(minutes: 5)),
      );
      expect(userValid.isTokenExpired, isFalse);

      // No expiry provided -> defaults to not expired
      final userNoExpiry = FirebridgeUser(
        id: 'u-4',
        email: 'test@example.com',
        displayName: 'Test User',
        accessToken: 'token-abc',
      );
      expect(userNoExpiry.isTokenExpired, isFalse);
    });

    test('User serialization and copyWith work as expected', () {
      final expiry = DateTime.parse('2026-11-14T12:00:00Z');
      final user = FirebridgeUser(
        id: 'u-123',
        email: 'dev@cloud.com',
        displayName: 'Cloud Dev',
        photoUrl: 'https://example.com/avatar.png',
        accessToken: 'token-xyz',
        idToken: 'jwt-token',
        tokenExpiry: expiry,
      );

      final json = user.toJson();
      expect(json['id'], 'u-123');
      expect(json['email'], 'dev@cloud.com');
      expect(json['tokenExpiry'], expiry.toIso8601String());

      final restored = FirebridgeUser.fromJson(json);
      expect(restored.id, user.id);
      expect(restored.email, user.email);
      expect(restored.displayName, user.displayName);
      expect(restored.photoUrl, user.photoUrl);
      expect(restored.accessToken, user.accessToken);

      final updated = user.copyWith(accessToken: 'token-new');
      expect(updated.accessToken, 'token-new');
      expect(updated.email, user.email);
    });
  });

  group('FirebridgeProject Tests', () {
    test('isReady is true only when both Firebase and Firestore are active', () {
      const p1 = FirebridgeProject(
        projectId: 'proj-1',
        projectNumber: '1001',
        name: 'Project One',
        isFirebaseEnabled: false,
        isFirestoreActive: false,
      );
      expect(p1.isReady, isFalse);

      const p2 = FirebridgeProject(
        projectId: 'proj-2',
        projectNumber: '1002',
        name: 'Project Two',
        isFirebaseEnabled: true,
        isFirestoreActive: false,
      );
      expect(p2.isReady, isFalse);

      const p3 = FirebridgeProject(
        projectId: 'proj-3',
        projectNumber: '1003',
        name: 'Project Three',
        isFirebaseEnabled: false,
        isFirestoreActive: true,
      );
      expect(p3.isReady, isFalse);

      const p4 = FirebridgeProject(
        projectId: 'proj-4',
        projectNumber: '1004',
        name: 'Project Four',
        isFirebaseEnabled: true,
        isFirestoreActive: true,
      );
      expect(p4.isReady, isTrue);
    });

    test('Project fromJson parses GCP CRM response correctly', () {
      final gcpJson = {
        'projectId': 'test-proj-42',
        'projectNumber': '987654321',
        'name': 'My Super Project',
        'lifecycleState': 'ACTIVE',
      };

      final proj = FirebridgeProject.fromJson(
        gcpJson,
        isFirebase: true,
        isFirestore: true,
        firestoreState: 'READY',
        location: 'nam5',
      );

      expect(proj.projectId, 'test-proj-42');
      expect(proj.projectNumber, '987654321');
      expect(proj.name, 'My Super Project');
      expect(proj.lifecycleState, 'ACTIVE');
      expect(proj.isFirebaseEnabled, isTrue);
      expect(proj.isFirestoreActive, isTrue);
      expect(proj.firestoreState, 'READY');
      expect(proj.firestoreLocation, 'nam5');
      expect(proj.isReady, isTrue);
    });
  });

  group('FirebridgeDocument Tests', () {
    test('fromRestJson decodes Firestore REST types into native Dart primitives', () {
      final restResponse = {
        'name': 'projects/p-123/databases/(default)/documents/notes/doc-999',
        'createTime': '2026-11-14T10:00:00Z',
        'updateTime': '2026-11-14T10:05:00Z',
        'fields': {
          'title': {'stringValue': 'Architecture Notes'},
          'content': {'stringValue': 'BYOC pattern in Flutter'},
          'author': {'stringValue': 'alice@example.com'},
          'viewCount': {'integerValue': '42'},
          'score': {'doubleValue': 98.5},
          'isPublished': {'booleanValue': true},
          'tags': {
            'arrayValue': {
              'values': [
                {'stringValue': 'flutter'},
                {'stringValue': 'firebase'},
              ]
            }
          },
          'metadata': {
            'mapValue': {
              'fields': {
                'env': {'stringValue': 'production'},
                'version': {'integerValue': '2'},
              }
            }
          },
          'deletedAt': {'nullValue': null},
        }
      };

      final doc = FirebridgeDocument.fromRestJson(restResponse);

      expect(doc.id, 'doc-999');
      expect(doc.path, 'projects/p-123/databases/(default)/documents/notes/doc-999');
      expect(doc.title, 'Architecture Notes');
      expect(doc.content, 'BYOC pattern in Flutter');
      expect(doc.createdBy, 'alice@example.com');
      expect(doc['viewCount'], 42);
      expect(doc['score'], 98.5);
      expect(doc['isPublished'], isTrue);
      expect(doc['tags'], ['flutter', 'firebase']);
      expect(doc['metadata'], {'env': 'production', 'version': 2});
      expect(doc['deletedAt'], isNull);
      expect(doc.createTime, DateTime.parse('2026-11-14T10:00:00Z'));
      expect(doc.updateTime, DateTime.parse('2026-11-14T10:05:00Z'));
    });

    test('toRestFields serializes native Dart types into Firestore REST format', () {
      final timestamp = DateTime.parse('2026-11-14T12:00:00Z');
      final dartData = {
        'title': 'Test Document',
        'count': 100,
        'rating': 4.8,
        'enabled': false,
        'created': timestamp,
        'optional': null,
        'sub': {
          'key': 'value',
        },
        'items': ['a', 'b', 3],
      };

      final restFields = FirebridgeDocument.toRestFields(dartData);

      expect(restFields['title'], {'stringValue': 'Test Document'});
      expect(restFields['count'], {'integerValue': '100'});
      expect(restFields['rating'], {'doubleValue': 4.8});
      expect(restFields['enabled'], {'booleanValue': false});
      expect(restFields['created'], {'timestampValue': '2026-11-14T12:00:00.000Z'});
      expect(restFields['optional'], {'nullValue': null});
      expect(restFields['sub'], {
        'mapValue': {
          'fields': {
            'key': {'stringValue': 'value'},
          }
        }
      });
      expect(restFields['items'], {
        'arrayValue': {
          'values': [
            {'stringValue': 'a'},
            {'stringValue': 'b'},
            {'integerValue': '3'},
          ]
        }
      });
    });

    test('Bidirectional round-trip retains data types faithfully', () {
      final original = {
        'title': 'Roundtrip Note',
        'count': 15,
        'active': true,
      };

      final restDoc = FirebridgeDocument.toRestDocument(original);
      final simulatedServerResponse = {
        'name': 'projects/demo/databases/(default)/documents/notes/rt-1',
        'fields': restDoc['fields'],
      };

      final doc = FirebridgeDocument.fromRestJson(simulatedServerResponse);
      expect(doc['title'], 'Roundtrip Note');
      expect(doc['count'], 15);
      expect(doc['active'], true);
    });
  });
}

