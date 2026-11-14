class FirebridgeConstants {
  // --- OAuth Scopes ---
  static const String scopeOpenId = 'openid';
  static const String scopeEmail = 'email';
  static const String scopeProfile = 'profile';
  static const String scopeCloudPlatform =
      'https://www.googleapis.com/auth/cloud-platform';
  static const String scopeDatastore =
      'https://www.googleapis.com/auth/datastore';
  static const String scopeFirebase =
      'https://www.googleapis.com/auth/firebase';

  static const List<String> defaultScopes = [
    scopeOpenId,
    scopeEmail,
    scopeProfile,
    scopeCloudPlatform,
    scopeDatastore,
    scopeFirebase,
  ];

  // --- Required Google Cloud Services ---
  static const List<String> requiredServices = [
    'serviceusage.googleapis.com',
    'firestore.googleapis.com',
    'datastore.googleapis.com',
    'firebase.googleapis.com',
    'firebaserules.googleapis.com',
  ];

  // --- API Endpoints ---
  static const String crmBase = 'https://cloudresourcemanager.googleapis.com/v1';
  static const String serviceUsageBase = 'https://serviceusage.googleapis.com/v1';
  static const String firebaseBase = 'https://firebase.googleapis.com/v1beta1';
  static const String firestoreBase = 'https://firestore.googleapis.com/v1';

  // CRM
  static String crmProjects({int pageSize = 100}) => '$crmBase/projects?pageSize=$pageSize';
  static String crmProject(String projectId) => '$crmBase/projects/$projectId';
  static String crmOperation(String operationName) => '$crmBase/$operationName';

  // Service Usage
  static String serviceUsageGet(String projectId, String serviceId) =>
      '$serviceUsageBase/projects/$projectId/services/$serviceId';
  static String serviceUsageEnable(String projectId, String serviceId) =>
      '$serviceUsageBase/projects/$projectId/services/$serviceId:enable';
  static String serviceUsageOperation(String operationName) =>
      '$serviceUsageBase/$operationName';

  // Firebase Management
  static String firebaseProjects({int pageSize = 100}) => '$firebaseBase/projects?pageSize=$pageSize';
  static String firebaseProject(String projectId) => '$firebaseBase/projects/$projectId';
  static String firebaseAdd(String projectId) => '$firebaseBase/projects/$projectId:addFirebase';
  static String firebaseOperation(String operationName) => '$firebaseBase/$operationName';

  // Firestore Admin
  static String firestoreDatabases(String projectId) =>
      '$firestoreBase/projects/$projectId/databases';
  static String firestoreDatabase(String projectId, [String databaseId = '(default)']) =>
      '$firestoreBase/projects/$projectId/databases/$databaseId';
  static String firestoreOperation(String operationName) => '$firestoreBase/$operationName';

  // Firestore REST Documents
  static String firestoreDocuments(String projectId, String collectionPath, {String databaseId = '(default)', int pageSize = 100}) =>
      '$firestoreBase/projects/$projectId/databases/$databaseId/documents/$collectionPath?pageSize=$pageSize';
  static String firestoreDocument(String projectId, String documentPath, {String databaseId = '(default)'}) =>
      '$firestoreBase/projects/$projectId/databases/$databaseId/documents/$documentPath';
}

