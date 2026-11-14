# Firebridge Developer Usage Guide 📖

Complete guide on how to integrate and use the **Firebridge Bring-Your-Own-Cloud (BYOC)** package in your Flutter applications.

---

## 1. Google Cloud Console Prerequisites

Because Firebridge allows end-users to bind their own Google Cloud infrastructure, you only need to configure an OAuth 2.0 Client for your application once:

### A. OAuth Consent Screen
1. Open [Google Cloud Console > APIs & Services > OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent).
2. Choose **External** user type.
3. Fill in App Name, User support email, and Developer contact information.
4. Add the following scopes:
   - `openid`
   - `email`
   - `profile`
   - `https://www.googleapis.com/auth/cloud-platform`
   - `https://www.googleapis.com/auth/datastore`
   - `https://www.googleapis.com/auth/firebase`

### B. Android Configuration
1. Open [Credentials](https://console.cloud.google.com/apis/credentials) > **Create Credentials** > **OAuth client ID**.
2. Select **Android**.
3. Enter your Android package name (e.g. `com.example.myapp`).
4. Generate and paste your development SHA-1 certificate fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

### C. Web Configuration (if targeting Flutter Web)
1. In Credentials, click **Create Credentials** > **OAuth client ID**.
2. Select **Web application**.
3. Under **Authorized JavaScript origins**, add your local and production hosts (e.g. `http://localhost:3000` or `https://myapp.web.app`).
4. Copy the generated **Client ID** for use in `Firebridge.initialize(webClientId: '...')`.

---

## 2. Package Installation

Add `firebridge` to your project's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebridge: ^0.0.1
```

Or run:

```bash
flutter pub add firebridge
```

---

## 3. Initialization in `main()`

Call `Firebridge.initialize()` inside your `main()` method before `runApp()`:

```dart
import 'package:flutter/material.dart';
import 'package:firebridge/firebridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebridge.initialize(
    enableLogging: true, // Set to true for debug logs, false for production
    webClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com', // Required for Web
    defaultRegion: 'nam5', // Regional or multi-region ID for Firestore
  );

  runApp(const MyApp());
}
```

---

## 4. Authentication

Firebridge provides multiplatform Google authentication with delegated cloud management scopes.

### 1-Tap Google Sign-In
```dart
try {
  final user = await Firebridge.auth.signIn();
  if (user != null) {
    print('Signed in as: ${user.displayName} (${user.email})');
  }
} on FirebridgeException catch (e) {
  FirebridgeErrorDialog.show(context, error: e);
}
```

### Direct OAuth Token Sign-In (Ideal for development / CI)
Bypasses OAuth consent screens during rapid testing:
```dart
// Generate token via: gcloud auth print-access-token
final user = await Firebridge.auth.signInWithToken('ya29.a0AfH6...');
```

### Checking Auth State & Sign-Out
```dart
// Check sign-in status
if (Firebridge.auth.isSignedIn) {
  final currentUser = Firebridge.auth.currentUser;
  print('Current User: ${currentUser?.email}');
}

// Sign out and clear stored tokens
await Firebridge.auth.signOut();
```

---

## 5. Project Discovery & Provisioning

### Option A: Drop-in Material 3 Widget (Recommended)

Drop `FirebridgeProjectPicker` into your widget tree to give users a complete UI for viewing their existing projects and creating new ones:

```dart
FirebridgeProjectPicker(
  onProjectSelected: (FirebridgeProject project) {
    // Project selected! Navigate to dashboard
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(project: project),
      ),
    );
  },
)
```

### Option B: Programmatic Project Management

```dart
// 1. List user's accessible projects
List<FirebridgeProject> projects = await Firebridge.projects.list();

// 2. Provision a brand-new project with Firebase & Firestore enabled
FirebridgeProject newProject = await Firebridge.projects.create(
  name: 'My Custom App Cloud',
  location: 'nam5',
  onProgress: (step, message) {
    print('Progress: [$step] $message');
  },
);
```

---

## 6. Cloud Firestore Operations (Fluent REST Client)

Bind to the active user's project with `Firebridge.use()` and execute CRUD operations with zero local SDK configuration files:

```dart
// 1. Bind to project
final app = Firebridge.use(selectedProject.projectId);

// 2. Collection reference
final collection = app.firestore.collection('notes');

// 3. Fetch all documents in collection
List<FirebridgeDocument> docs = await collection.get();
for (final doc in docs) {
  print('ID: ${doc.id}');
  print('Title: ${doc['title']}');
  print('Created by: ${doc.createdBy}');
  print('Created at: ${doc.createdAt}');
}

// 4. Add a new document (auto-generates server UTC timestamp and ID)
FirebridgeDocument createdDoc = await collection.add({
  'title': 'My Confidential Note',
  'content': 'Stored directly in my own Google Cloud instance!',
  'isEncrypted': true,
  'priority': 1,
});

// 5. Read a specific document by ID
FirebridgeDocument? singleDoc = await collection.doc(createdDoc.id).get();

// 6. Update document with field merging
await collection.doc(createdDoc.id).set({
  'content': 'Updated content with merge protection.',
}, merge: true);

// 7. Delete document
await collection.doc(createdDoc.id).delete();
```

---

## 7. Error Handling & Troubleshooting

Whenever an error occurs, Firebridge wraps it in a typed `FirebridgeException` with actionable recovery instructions. Show the built-in dialog:

```dart
try {
  await app.firestore.collection('notes').add({'data': 'test'});
} on FirebridgeException catch (e) {
  FirebridgeErrorDialog.show(
    context,
    error: e,
    onRetry: () => retryOperation(),
  );
}
```

For a complete directory of error codes and resolution steps, refer to [ERRORS.md](ERRORS.md).

