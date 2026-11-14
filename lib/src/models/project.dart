/// Model representing a Google Cloud / Firebase project discovered or provisioned by Firebridge.
class FirebridgeProject {
  /// The unique GCP project ID (e.g. "byof-notes-48291").
  final String projectId;

  /// The unique numeric project number assigned by Google Cloud.
  final String projectNumber;

  /// The human-readable project display name.
  final String name;

  /// Current GCP project lifecycle state (e.g. "ACTIVE", "DELETE_REQUESTED").
  final String lifecycleState;

  /// Whether Firebase management has been enabled on this GCP project.
  final bool isFirebaseEnabled;

  /// Whether Cloud Firestore database exists and is active.
  final bool isFirestoreActive;

  /// The operational state of the Firestore database (e.g. "READY", "INITIALIZING").
  final String? firestoreState;

  /// The multi-region or regional location ID (e.g. "nam5", "us-central1").
  final String? firestoreLocation;

  const FirebridgeProject({
    required this.projectId,
    required this.projectNumber,
    required this.name,
    this.lifecycleState = 'ACTIVE',
    this.isFirebaseEnabled = false,
    this.isFirestoreActive = false,
    this.firestoreState,
    this.firestoreLocation,
  });

  /// True when the project has Firebase enabled and its Firestore database is ready.
  bool get isReady => isFirebaseEnabled && isFirestoreActive;

  /// Constructs a project from Google Cloud Resource Manager JSON with optional Firebase/Firestore flags.
  factory FirebridgeProject.fromJson(
    Map<String, dynamic> json, {
    bool isFirebase = false,
    bool isFirestore = false,
    String? firestoreState,
    String? location,
  }) {
    return FirebridgeProject(
      projectId: json['projectId'] as String? ?? '',
      projectNumber: json['projectNumber'] as String? ?? '',
      name: json['name'] as String? ?? (json['projectId'] as String? ?? ''),
      lifecycleState: json['lifecycleState'] as String? ?? 'ACTIVE',
      isFirebaseEnabled: isFirebase,
      isFirestoreActive: isFirestore,
      firestoreState: firestoreState,
      firestoreLocation: location,
    );
  }

  /// Creates a copy with optional updated fields.
  FirebridgeProject copyWith({
    String? projectId,
    String? projectNumber,
    String? name,
    String? lifecycleState,
    bool? isFirebaseEnabled,
    bool? isFirestoreActive,
    String? firestoreState,
    String? firestoreLocation,
  }) {
    return FirebridgeProject(
      projectId: projectId ?? this.projectId,
      projectNumber: projectNumber ?? this.projectNumber,
      name: name ?? this.name,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      isFirebaseEnabled: isFirebaseEnabled ?? this.isFirebaseEnabled,
      isFirestoreActive: isFirestoreActive ?? this.isFirestoreActive,
      firestoreState: firestoreState ?? this.firestoreState,
      firestoreLocation: firestoreLocation ?? this.firestoreLocation,
    );
  }

  /// Converts this project to a JSON map.
  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'projectNumber': projectNumber,
        'name': name,
        'lifecycleState': lifecycleState,
        'isFirebaseEnabled': isFirebaseEnabled,
        'isFirestoreActive': isFirestoreActive,
        'firestoreState': firestoreState,
        'firestoreLocation': firestoreLocation,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebridgeProject &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          projectNumber == other.projectNumber &&
          isFirebaseEnabled == other.isFirebaseEnabled &&
          isFirestoreActive == other.isFirestoreActive;

  @override
  int get hashCode =>
      projectId.hashCode ^
      projectNumber.hashCode ^
      isFirebaseEnabled.hashCode ^
      isFirestoreActive.hashCode;

  @override
  String toString() =>
      'FirebridgeProject(id: $projectId, name: $name, state: $lifecycleState, ready: $isReady)';
}

