import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/logger.dart';
import '../models/document.dart';

/// App instance bound to a specific Google Cloud project and Firestore database.
class FirebridgeApp {
  /// The bound Google Cloud project ID.
  final String projectId;

  /// The target Firestore database ID (defaults to `(default)`).
  final String databaseId;

  /// Provider for fresh OAuth access tokens.
  final Future<String> Function() getAccessToken;

  /// HTTP client used for requests.
  final http.Client client;

  /// The fluent Cloud Firestore REST client.
  late final FirestoreRestClient firestore;

  FirebridgeApp({
    required this.projectId,
    this.databaseId = '(default)',
    required this.getAccessToken,
    http.Client? client,
  }) : client = client ?? http.Client() {
    firestore = FirestoreRestClient(
      projectId: projectId,
      databaseId: databaseId,
      getAccessToken: getAccessToken,
      client: this.client,
    );
  }
}

/// Fluent entry point for Cloud Firestore REST operations.
class FirestoreRestClient {
  final String projectId;
  final String databaseId;
  final Future<String> Function() getAccessToken;
  final http.Client client;

  FirestoreRestClient({
    required this.projectId,
    this.databaseId = '(default)',
    required this.getAccessToken,
    http.Client? client,
  }) : client = client ?? http.Client();

  /// Gets a [CollectionReference] for the specified collection path.
  CollectionReference collection(String collectionPath) {
    // Strip leading or trailing slashes
    final cleanPath = collectionPath.replaceAll(RegExp(r'^/|/$'), '');
    return CollectionReference(
      projectId: projectId,
      databaseId: databaseId,
      path: cleanPath,
      getAccessToken: getAccessToken,
      client: client,
    );
  }
}

/// Reference to a Firestore collection providing document querying and creation.
class CollectionReference {
  static const String _tag = 'CollectionReference';

  final String projectId;
  final String databaseId;
  final String path;
  final Future<String> Function() getAccessToken;
  final http.Client client;

  CollectionReference({
    required this.projectId,
    required this.databaseId,
    required this.path,
    required this.getAccessToken,
    required this.client,
  });

  String get _collectionUrl =>
      '${FirebridgeConstants.firestoreBase}/projects/$projectId/databases/$databaseId/documents/$path';

  /// Fetches all documents in this collection.
  Future<List<FirebridgeDocument>> get() async {
    final token = await getAccessToken();
    FirebridgeLogger.i('Fetching collection: $path on $projectId...', _tag);

    final url = Uri.parse('$_collectionUrl?pageSize=100');
    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['documents'] as List<dynamic>? ?? [];
      FirebridgeLogger.i('Fetched ${list.length} documents from $path', _tag);
      return list
          .map((d) => FirebridgeDocument.fromRestJson(d as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 404) {
      // Collection does not exist yet or has no documents
      FirebridgeLogger.i('Collection $path not found or empty (404)', _tag);
      return [];
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to fetch collection "$path"',
    );
  }

  /// Adds a new document with an auto-generated Firestore ID.
  Future<FirebridgeDocument> add(Map<String, dynamic> data) async {
    final token = await getAccessToken();
    FirebridgeLogger.i('Adding document to collection: $path on $projectId...', _tag);

    // Auto-populate createdAt if omitted
    final payloadData = Map<String, dynamic>.from(data);
    if (!payloadData.containsKey('createdAt')) {
      payloadData['createdAt'] = DateTime.now().toUtc();
    }

    final requestBody = FirebridgeDocument.toRestDocument(payloadData);
    final url = Uri.parse(_collectionUrl);

    final response = await client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final createdDoc = FirebridgeDocument.fromRestJson(responseData);
      FirebridgeLogger.i('Added document ${createdDoc.id} to $path', _tag);
      return createdDoc;
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to add document to "$path"',
    );
  }

  /// Returns a [DocumentReference] pointing to the child document with [documentId].
  DocumentReference doc(String documentId) {
    final cleanId = documentId.replaceAll(RegExp(r'^/|/$'), '');
    return DocumentReference(
      projectId: projectId,
      databaseId: databaseId,
      path: '$path/$cleanId',
      id: cleanId,
      getAccessToken: getAccessToken,
      client: client,
    );
  }
}

/// Reference to a specific Firestore document providing read, set, and delete operations.
class DocumentReference {
  static const String _tag = 'DocumentReference';

  final String projectId;
  final String databaseId;
  final String path;
  final String id;
  final Future<String> Function() getAccessToken;
  final http.Client client;

  DocumentReference({
    required this.projectId,
    required this.databaseId,
    required this.path,
    required this.id,
    required this.getAccessToken,
    required this.client,
  });

  String get _documentUrl =>
      '${FirebridgeConstants.firestoreBase}/projects/$projectId/databases/$databaseId/documents/$path';

  /// Reads the document from Cloud Firestore. Returns null if document does not exist.
  Future<FirebridgeDocument?> get() async {
    final token = await getAccessToken();
    FirebridgeLogger.i('Reading document: $path...', _tag);

    final url = Uri.parse(_documentUrl);
    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return FirebridgeDocument.fromRestJson(data);
    } else if (response.statusCode == 404) {
      FirebridgeLogger.i('Document $path not found (404)', _tag);
      return null;
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to read document "$path"',
    );
  }

  /// Sets or updates the document data.
  /// If [merge] is true, only the keys in [data] will be updated or created (PATCH with updateMask).
  Future<void> set(Map<String, dynamic> data, {bool merge = false}) async {
    final token = await getAccessToken();
    FirebridgeLogger.i('Setting document: $path (merge: $merge)...', _tag);

    final requestBody = FirebridgeDocument.toRestDocument(data);

    Uri url;
    if (merge && data.isNotEmpty) {
      final queryParams = data.keys
          .map((k) => 'updateMask.fieldPaths=$k')
          .join('&');
      url = Uri.parse('$_documentUrl?$queryParams');
    } else {
      url = Uri.parse(_documentUrl);
    }

    final response = await client.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      FirebridgeLogger.i('Successfully wrote document $path', _tag);
      return;
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to write document "$path"',
    );
  }

  /// Deletes the document from Cloud Firestore.
  Future<void> delete() async {
    final token = await getAccessToken();
    FirebridgeLogger.i('Deleting document: $path...', _tag);

    final url = Uri.parse(_documentUrl);
    final response = await client.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200 ||
        response.statusCode == 204 ||
        response.statusCode == 404) {
      FirebridgeLogger.i('Deleted document $path', _tag);
      return;
    }

    throw FirebridgeException.fromResponse(
      response,
      customMessage: 'Failed to delete document "$path"',
    );
  }
}
