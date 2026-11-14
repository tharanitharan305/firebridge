import 'dart:math';

import '../core/errors.dart';
import '../core/logger.dart';
import '../models/project.dart';
import 'crm_service.dart';
import 'firebase_mgmt_service.dart';
import 'firestore_admin_service.dart';
import 'service_usage_service.dart';

/// Steps in the automated Firebridge BYOC provisioning pipeline.
enum ProvisioningStep {
  generatingId('1/6: Generating unique Project ID', 0.1),
  creatingProject('2/6: Creating Google Cloud project', 0.25),
  enablingApis('3/6: Enabling Firebase & Firestore APIs', 0.5),
  addingFirebase('4/6: Adding Firebase capability', 0.7),
  creatingFirestore('5/6: Provisioning Native Firestore database', 0.85),
  verifying('6/6: Verifying database readiness', 0.95),
  completed('Provisioning complete', 1.0);

  final String description;
  final double progress;
  const ProvisioningStep(this.description, this.progress);
}

/// Progress event emitted during project provisioning.
class ProvisioningProgress {
  final ProvisioningStep step;
  final String message;
  final double percentage;

  const ProvisioningProgress({
    required this.step,
    required this.message,
    required this.percentage,
  });

  @override
  String toString() =>
      'ProvisioningProgress(step: ${step.name}, message: $message, percent: ${(percentage * 100).toInt()}%)';
}

/// Orchestrates the end-to-end automated BYOC provisioning pipeline.
class FirebridgeProvisioningEngine {
  static const String _tag = 'ProvisioningEngine';

  final CloudResourceManagerService crmService;
  final ServiceUsageService serviceUsageService;
  final FirebaseManagementService firebaseService;
  final FirestoreAdminService firestoreAdminService;

  FirebridgeProvisioningEngine({
    required this.crmService,
    required this.serviceUsageService,
    required this.firebaseService,
    required this.firestoreAdminService,
  });

  /// Validates whether a project ID strictly satisfies Google Cloud naming rules:
  /// - 6 to 30 characters
  /// - Lowercase letters, digits, and hyphens only
  /// - Must start with a lowercase letter
  /// - Must not end with a hyphen
  static bool isValidProjectId(String id) {
    final regex = RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$');
    return regex.hasMatch(id);
  }

  /// Generates a globally randomized, GCP-compliant project ID.
  static String generateUniqueProjectId({String prefix = 'fb-byof'}) {
    final random = Random();
    final randomSuffix = List.generate(6, (_) => random.nextInt(10)).join();
    final candidate = '$prefix-$randomSuffix'.toLowerCase();
    if (candidate.length > 30) {
      return candidate.substring(0, 30);
    }
    return candidate;
  }

  /// Executes the 6-step provisioning workflow.
  Future<FirebridgeProject> provision({
    String? projectId,
    String? projectName,
    String locationId = 'nam5',
    void Function(ProvisioningProgress progress)? onProgress,
  }) async {
    final targetProjectId = (projectId != null && projectId.isNotEmpty)
        ? projectId.toLowerCase().trim()
        : generateUniqueProjectId();

    if (!isValidProjectId(targetProjectId)) {
      throw FirebridgeProvisioningException(
        code: FirebridgeErrorCodes.projectCollision,
        message:
            'Project ID "$targetProjectId" is invalid. Google Cloud project IDs must be 6-30 characters, '
            'contain only lowercase letters, numbers, and hyphens, and start with a letter.',
        resolutionSteps: 'Provide a valid project ID matching `[a-z][a-z0-9-]{4,28}[a-z0-9]`.',
      );
    }

    final targetName = projectName ?? 'Firebridge App';

    FirebridgeLogger.i('Beginning provisioning pipeline for $targetProjectId...', _tag);

    // Step 1: Generating ID
    onProgress?.call(ProvisioningProgress(
      step: ProvisioningStep.generatingId,
      message: 'Configured project ID: $targetProjectId',
      percentage: ProvisioningStep.generatingId.progress,
    ));

    // Step 2: Create Google Cloud Project
    onProgress?.call(ProvisioningProgress(
      step: ProvisioningStep.creatingProject,
      message: 'Creating Google Cloud project "$targetName"...',
      percentage: ProvisioningStep.creatingProject.progress,
    ));
    try {
      final opName = await crmService.createProject(
        projectId: targetProjectId,
        projectName: targetName,
      );

      if (opName != 'done') {
        onProgress?.call(ProvisioningProgress(
          step: ProvisioningStep.creatingProject,
          message: 'Waiting for project creation operation...',
          percentage: ProvisioningStep.creatingProject.progress + 0.1,
        ));
        await crmService.pollOperation(
          opName,
          onProgress: (msg) => onProgress?.call(ProvisioningProgress(
            step: ProvisioningStep.creatingProject,
            message: msg,
            percentage: ProvisioningStep.creatingProject.progress + 0.15,
          )),
        );
      }
      FirebridgeLogger.i('GCP project $targetProjectId confirmed active', _tag);
    } catch (e) {
      FirebridgeLogger.e('Step 2 (CRM Project Creation) failed', e, null, _tag);
      rethrow;
    }

    // Step 3: Enable Required APIs
    onProgress?.call(ProvisioningProgress(
      step: ProvisioningStep.enablingApis,
      message: 'Enabling required Google Cloud APIs (firestore, firebase, rules)...',
      percentage: ProvisioningStep.enablingApis.progress,
    ));
    try {
      await serviceUsageService.enableAllRequiredServices(
        targetProjectId,
        onProgress: (msg) => onProgress?.call(ProvisioningProgress(
          step: ProvisioningStep.enablingApis,
          message: msg,
          percentage: ProvisioningStep.enablingApis.progress + 0.1,
        )),
      );
    } catch (e) {
      FirebridgeLogger.e('Step 3 (Service Enablement) failed', e, null, _tag);
      rethrow;
    }

    // Step 4: Add Firebase to Project
    onProgress?.call(ProvisioningProgress(
      step: ProvisioningStep.addingFirebase,
      message: 'Associating Firebase management with project...',
      percentage: ProvisioningStep.addingFirebase.progress,
    ));
    try {
      await firebaseService.addFirebase(
        targetProjectId,
        onProgress: (msg) => onProgress?.call(ProvisioningProgress(
          step: ProvisioningStep.addingFirebase,
          message: msg,
          percentage: ProvisioningStep.addingFirebase.progress + 0.05,
        )),
      );
    } catch (e) {
      FirebridgeLogger.e('Step 4 (Add Firebase) failed', e, null, _tag);
      rethrow;
    }

    // Step 5: Create Native Firestore Database
    onProgress?.call(ProvisioningProgress(
      step: ProvisioningStep.creatingFirestore,
      message: 'Creating Native Firestore (default) database in $locationId...',
      percentage: ProvisioningStep.creatingFirestore.progress,
    ));
    try {
      await firestoreAdminService.createDatabase(
        projectId: targetProjectId,
        locationId: locationId,
        onProgress: (msg) => onProgress?.call(ProvisioningProgress(
          step: ProvisioningStep.creatingFirestore,
          message: msg,
          percentage: ProvisioningStep.creatingFirestore.progress + 0.05,
        )),
      );
    } catch (e) {
      FirebridgeLogger.e('Step 5 (Create Firestore Database) failed', e, null, _tag);
      rethrow;
    }

    // Step 6: Verify Database
    onProgress?.call(ProvisioningProgress(
      step: ProvisioningStep.verifying,
      message: 'Verifying database operational status...',
      percentage: ProvisioningStep.verifying.progress,
    ));

    final dbInfo = await firestoreAdminService.checkDatabase(targetProjectId);
    if (!dbInfo.exists) {
      throw const FirebridgeNotFoundException(
        code: FirebridgeErrorCodes.propagationTimeout,
        message: 'Firestore database was provisioned but could not be verified yet. Propagation may be in progress.',
        resolutionSteps: 'Wait 30 seconds and retry connecting to your project.',
        helpUrl: 'https://console.firebase.google.com',
      );
    }

    onProgress?.call(ProvisioningProgress(
      step: ProvisioningStep.completed,
      message: 'Project and Firestore ready for use!',
      percentage: ProvisioningStep.completed.progress,
    ));

    FirebridgeLogger.i('Provisioning completed successfully for $targetProjectId!', _tag);

    return FirebridgeProject(
      projectId: targetProjectId,
      projectNumber: '',
      name: targetName,
      lifecycleState: 'ACTIVE',
      isFirebaseEnabled: true,
      isFirestoreActive: true,
      firestoreState: dbInfo.state ?? 'READY',
      firestoreLocation: dbInfo.locationId ?? locationId,
    );
  }
}

