/// Model representing a Cloud Firestore document accessed via REST API.
class FirebridgeDocument {
  /// Unique document ID (the final segment in the document resource path).
  final String id;

  /// Full resource path (e.g. "projects/p/databases/(default)/documents/col/id").
  final String path;

  /// Decoded key-value data fields mapped to native Dart primitives.
  final Map<String, dynamic> data;

  /// Creation timestamp extracted from document fields or GCP metadata.
  final DateTime? createdAt;

  /// Author / creator ID or email extracted from document fields.
  final String? createdBy;

  /// Server-managed document creation timestamp (RFC 3339).
  final DateTime? createTime;

  /// Server-managed document update timestamp (RFC 3339).
  final DateTime? updateTime;

  /// Preserved raw Firestore REST fields if needed for low-level inspection.
  final Map<String, dynamic> rawFields;

  const FirebridgeDocument({
    required this.id,
    required this.path,
    required this.data,
    this.createdAt,
    this.createdBy,
    this.createTime,
    this.updateTime,
    this.rawFields = const {},
  });

  /// Index operator for fast access to document fields: `doc['title']`.
  dynamic operator [](String key) => data[key];

  /// Convenience getter for `content` or `text` or `message` field.
  String? get content =>
      data['content'] as String? ??
      data['text'] as String? ??
      data['message'] as String?;

  /// Convenience getter for `title` or `name` field.
  String? get title =>
      data['title'] as String? ?? data['name'] as String?;

  /// Parses a Cloud Firestore REST response JSON into a [FirebridgeDocument].
  factory FirebridgeDocument.fromRestJson(Map<String, dynamic> json) {
    final fullName = json['name'] as String? ?? '';
    final id = fullName.split('/').last;
    final rawFields = json['fields'] as Map<String, dynamic>? ?? {};

    // Decode REST typed fields into native Dart primitives
    final decodedData = <String, dynamic>{};
    for (final entry in rawFields.entries) {
      decodedData[entry.key] = decodeRestValue(entry.value);
    }

    // Extract createdBy
    final createdBy = decodedData['createdBy'] as String? ??
        decodedData['author'] as String? ??
        decodedData['user'] as String?;

    // Extract createdAt timestamp
    DateTime? createdAt;
    final rawCreatedAt = decodedData['createdAt'];
    if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = _parseDateTime(rawCreatedAt);
    }

    final createTime = _parseDateTime(json['createTime'] as String?);
    final updateTime = _parseDateTime(json['updateTime'] as String?);
    createdAt ??= createTime;

    return FirebridgeDocument(
      id: id,
      path: fullName,
      data: decodedData,
      createdAt: createdAt,
      createdBy: createdBy,
      createTime: createTime,
      updateTime: updateTime,
      rawFields: rawFields,
    );
  }

  /// Converts a native Dart value into a Firestore REST typed value map.
  static Map<String, dynamic> encodeValue(dynamic value) {
    if (value == null) {
      return {'nullValue': null};
    }
    if (value is bool) {
      return {'booleanValue': value};
    }
    if (value is int) {
      return {'integerValue': value.toString()};
    }
    if (value is double) {
      return {'doubleValue': value};
    }
    if (value is String) {
      return {'stringValue': value};
    }
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is Map) {
      final nestedFields = <String, dynamic>{};
      for (final entry in value.entries) {
        nestedFields[entry.key.toString()] = encodeValue(entry.value);
      }
      return {
        'mapValue': {'fields': nestedFields}
      };
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(encodeValue).toList(),
        }
      };
    }
    // Fallback: encode as string
    return {'stringValue': value.toString()};
  }

  /// Converts a native Dart Map of fields into a Firestore REST `fields` map.
  static Map<String, dynamic> toRestFields(Map<String, dynamic> dartMap) {
    final fields = <String, dynamic>{};
    for (final entry in dartMap.entries) {
      fields[entry.key] = encodeValue(entry.value);
    }
    return fields;
  }

  /// Wraps a native Dart Map into the full Firestore document body `{ "fields": { ... } }`.
  static Map<String, dynamic> toRestDocument(Map<String, dynamic> dartMap) {
    return {
      'fields': toRestFields(dartMap),
    };
  }

  /// Decodes a Firestore REST typed value map into a native Dart primitive.
  static dynamic decodeRestValue(dynamic fieldObj) {
    if (fieldObj is! Map) return fieldObj;

    if (fieldObj.containsKey('stringValue')) {
      return fieldObj['stringValue'] as String;
    }
    if (fieldObj.containsKey('integerValue')) {
      final val = fieldObj['integerValue'];
      return int.tryParse(val.toString()) ?? val;
    }
    if (fieldObj.containsKey('doubleValue')) {
      final val = fieldObj['doubleValue'];
      return (val as num).toDouble();
    }
    if (fieldObj.containsKey('booleanValue')) {
      return fieldObj['booleanValue'] as bool;
    }
    if (fieldObj.containsKey('timestampValue')) {
      return _parseDateTime(fieldObj['timestampValue'] as String);
    }
    if (fieldObj.containsKey('nullValue')) {
      return null;
    }
    if (fieldObj.containsKey('referenceValue')) {
      return fieldObj['referenceValue'] as String;
    }
    if (fieldObj.containsKey('bytesValue')) {
      return fieldObj['bytesValue'] as String;
    }
    if (fieldObj.containsKey('mapValue')) {
      final mapValue = fieldObj['mapValue'] as Map<String, dynamic>? ?? {};
      final nestedFields = mapValue['fields'] as Map<String, dynamic>? ?? {};
      final result = <String, dynamic>{};
      for (final entry in nestedFields.entries) {
        result[entry.key] = decodeRestValue(entry.value);
      }
      return result;
    }
    if (fieldObj.containsKey('arrayValue')) {
      final arrayValue = fieldObj['arrayValue'] as Map<String, dynamic>? ?? {};
      final values = arrayValue['values'] as List<dynamic>? ?? [];
      return values.map(decodeRestValue).toList();
    }

    return fieldObj;
  }

  static DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Creates a copy with optional updated fields.
  FirebridgeDocument copyWith({
    String? id,
    String? path,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    String? createdBy,
    DateTime? createTime,
    DateTime? updateTime,
    Map<String, dynamic>? rawFields,
  }) {
    return FirebridgeDocument(
      id: id ?? this.id,
      path: path ?? this.path,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      rawFields: rawFields ?? this.rawFields,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebridgeDocument &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path;

  @override
  int get hashCode => id.hashCode ^ path.hashCode;

  @override
  String toString() =>
      'FirebridgeDocument(id: $id, path: $path, dataKeys: ${data.keys.toList()})';
}

