import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebridge/src/core/errors.dart';
import 'package:firebridge/src/services/firestore_client.dart';

void main() {
  Future<String> getMockToken() async => 'mock-firestore-token';

  group('Firestore Client Tests', () {
    test('Path formatting and chaining works correctly', () {
      final app = FirebridgeApp(
        projectId: 'test-byof-project',
        getAccessToken: getMockToken,
      );

      final col = app.firestore.collection('notes');
      expect(col.path, 'notes');

      final doc = col.doc('note-123');
      expect(doc.id, 'note-123');
      expect(doc.path, 'notes/note-123');
    });

    test('collection.get() returns list of parsed FirebridgeDocuments', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer mock-firestore-token');
        expect(request.url.toString(), contains('/documents/todos?pageSize=100'));

        return http.Response(
          jsonEncode({
            'documents': [
              {
                'name': 'projects/test-proj/databases/(default)/documents/todos/t1',
                'fields': {
                  'title': {'stringValue': 'Buy groceries'},
                  'completed': {'booleanValue': false},
                }
              },
              {
                'name': 'projects/test-proj/databases/(default)/documents/todos/t2',
                'fields': {
                  'title': {'stringValue': 'Deploy to App Store'},
                  'completed': {'booleanValue': true},
                }
              },
            ]
          }),
          200,
        );
      });

      final app = FirebridgeApp(
        projectId: 'test-proj',
        getAccessToken: getMockToken,
        client: mockClient,
      );

      final docs = await app.firestore.collection('todos').get();
      expect(docs.length, 2);
      expect(docs[0].id, 't1');
      expect(docs[0]['title'], 'Buy groceries');
      expect(docs[0]['completed'], isFalse);
      expect(docs[1].id, 't2');
      expect(docs[1]['title'], 'Deploy to App Store');
      expect(docs[1]['completed'], isTrue);
    });

    test('collection.get() returns empty list on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Not found"}', 404);
      });

      final app = FirebridgeApp(
        projectId: 'test-proj',
        getAccessToken: getMockToken,
        client: mockClient,
      );

      final docs = await app.firestore.collection('empty_collection').get();
      expect(docs, isEmpty);
    });

    test('collection.add() sends REST document with auto timestamp', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final fields = body['fields'] as Map<String, dynamic>;

        expect(fields['task']['stringValue'], 'Read book');
        expect(fields['createdAt']['timestampValue'], isNotNull);

        return http.Response(
          jsonEncode({
            'name': 'projects/test-proj/databases/(default)/documents/notes/auto-id-99',
            'fields': fields,
          }),
          200,
        );
      });

      final app = FirebridgeApp(
        projectId: 'test-proj',
        getAccessToken: getMockToken,
        client: mockClient,
      );

      final doc = await app.firestore.collection('notes').add({
        'task': 'Read book',
      });

      expect(doc.id, 'auto-id-99');
      expect(doc['task'], 'Read book');
    });

    test('doc.get() returns single document or null when 404', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('/doc-found')) {
          return http.Response(
            jsonEncode({
              'name': 'projects/test-proj/databases/(default)/documents/notes/doc-found',
              'fields': {
                'title': {'stringValue': 'Existing Note'},
              }
            }),
            200,
          );
        }
        return http.Response('{"error": "Not found"}', 404);
      });

      final app = FirebridgeApp(
        projectId: 'test-proj',
        getAccessToken: getMockToken,
        client: mockClient,
      );

      final existingDoc = await app.firestore.collection('notes').doc('doc-found').get();
      expect(existingDoc, isNotNull);
      expect(existingDoc!.id, 'doc-found');
      expect(existingDoc['title'], 'Existing Note');

      final missingDoc = await app.firestore.collection('notes').doc('doc-missing').get();
      expect(missingDoc, isNull);
    });

    test('doc.set() with merge adds updateMask query parameters', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response(jsonEncode({'name': 'doc-path'}), 200);
      });

      final app = FirebridgeApp(
        projectId: 'test-proj',
        getAccessToken: getMockToken,
        client: mockClient,
      );

      await app.firestore.collection('settings').doc('user-pref').set(
        {'theme': 'dark', 'notifications': true},
        merge: true,
      );

      expect(capturedUrl, contains('updateMask.fieldPaths=theme'));
      expect(capturedUrl, contains('updateMask.fieldPaths=notifications'));
    });

    test('doc.delete() deletes document cleanly', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        return http.Response('', 204);
      });

      final app = FirebridgeApp(
        projectId: 'test-proj',
        getAccessToken: getMockToken,
        client: mockClient,
      );

      await app.firestore.collection('items').doc('item-1').delete();
    });

    test('Throws FirebridgeException on 403 Permission Denied', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'status': 'PERMISSION_DENIED',
              'message': 'Missing Datastore User IAM permission',
            }
          }),
          403,
        );
      });

      final app = FirebridgeApp(
        projectId: 'test-proj',
        getAccessToken: getMockToken,
        client: mockClient,
      );

      expect(
        () => app.firestore.collection('restricted').get(),
        throwsA(isA<FirebridgePermissionException>()),
      );
    });
  });
}

