import 'crm_service.dart';
import 'firebase_mgmt_service.dart';
import 'firestore_admin_service.dart';
import 'provisioning_engine.dart';
import '../models/project.dart';

/// Contract for discovering, inspecting, and provisioning Google Cloud & Firebase projects.
abstract class FirebridgeProjectService {
  /// Lists all accessible Google Cloud projects with their Firebase status populated.
  Future<List<FirebridgeProject>> list();

  /// Provisions a brand-new Google Cloud project with Firebase and Native Firestore enabled.
  Future<FirebridgeProject> create({
    required String name,
    String? projectId,
    String location = 'nam5',
    void Function(String step, String message)? onProgress,
  });

  /// Deeply inspects an existing project to determine its Firebase and Firestore readiness.
  Future<FirebridgeProject> inspect(String projectId);
}

/// Production implementation of [FirebridgeProjectService].
class FirebridgeProjectServiceImpl implements FirebridgeProjectService {
  final CloudResourceManagerService crmService;
  final FirebaseManagementService firebaseService;
  final FirestoreAdminService firestoreAdminService;
  final FirebridgeProvisioningEngine provisioningEngine;

  FirebridgeProjectServiceImpl({
    required this.crmService,
    required this.firebaseService,
    required this.firestoreAdminService,
    required this.provisioningEngine,
  });

  @override
  Future<List<FirebridgeProject>> list() async {
    // 1. Fetch CRM projects
    final crmProjects = await crmService.listProjects();

    // 2. Fetch list of Firebase-enabled project IDs
    final firebaseIds = await firebaseService.listFirebaseProjectIds();

    // 3. Merge Firebase status
    return crmProjects.map((p) {
      final isFirebase = firebaseIds.contains(p.projectId);
      return p.copyWith(isFirebaseEnabled: isFirebase);
    }).toList();
  }

  @override
  Future<FirebridgeProject> create({
    required String name,
    String? projectId,
    String location = 'nam5',
    void Function(String step, String message)? onProgress,
  }) async {
    return provisioningEngine.provision(
      projectId: projectId,
      projectName: name,
      locationId: location,
      onProgress: onProgress != null
          ? (progress) => onProgress(progress.step.name, progress.message)
          : null,
    );
  }

  @override
  Future<FirebridgeProject> inspect(String projectId) async {
    final isFirebase = await firebaseService.isFirebaseEnabled(projectId);
    final dbInfo = await firestoreAdminService.checkDatabase(projectId);

    return FirebridgeProject(
      projectId: projectId,
      projectNumber: '',
      name: projectId,
      lifecycleState: 'ACTIVE',
      isFirebaseEnabled: isFirebase,
      isFirestoreActive: dbInfo.isReady,
      firestoreState: dbInfo.state,
      firestoreLocation: dbInfo.locationId,
    );
  }
}

