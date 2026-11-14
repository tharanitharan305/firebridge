# Firebridge 🌉

**Bring-Your-Own-Cloud (BYOC) for Flutter.** Connect end-users directly to their own Google Cloud and Cloud Firestore instances with **zero central developer database, zero multi-tenant liability, and zero cloud hosting bill.**

[![pub package](https://img.shields.io/badge/pub-v0.0.1-blue.svg)](https://pub.dev)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![tests](https://img.shields.io/badge/tests-34%20passing-brightgreen.svg)](#)

---

## Why Firebridge?

| Traditional Firebase | Firebridge BYOC |
|---|---|
| Developer pays for all users' reads, writes, and storage. | **Users pay Google directly or use Google's free tier.** |
| Developer stores everyone's private data in one central DB. | **Users own 100% of their private data in their own GCP project.** |
| Single project breach compromises all user data. | **Zero-knowledge architecture**: Developer has zero access to user data. |
| Hard-coded static `google-services.json` per app. | **Dynamic runtime binding** to any user GCP project via OAuth2. |

---

## Features

- 📱 **Multiplatform**: Seamless support for Android, Web, and iOS.
- 🪶 **Ultra-Lightweight**: Built entirely on standard Google Cloud REST APIs (`http`). No heavyweight native C++ Firebase SDK binaries or static configuration files.
- 🛠️ **Configurable Logging**: Toggle `enableLogging: true / false` with automatic redaction of OAuth bearer tokens and secrets.
- 🚨 **Actionable Error Diagnostics**: Typed error catalog with clear explanations, step-by-step resolution steps, and direct clickable links to Google Cloud Console.
- ⚡ **Automated 6-Step Provisioning Engine**: Generates unique GCP project IDs, creates the project, enables required APIs (`firestore`, `datastore`, `firebase`), creates Native Firestore databases with propagation retry, and verifies readiness.
- 🎨 **Plug-and-Play UI Widgets**: Drop-in `FirebridgeProjectPicker` and `FirebridgeErrorDialog` for instantaneous Material 3 integration.

---

## Installation

Add `firebridge` to your `pubspec.yaml`:

```yaml
dependencies:
  firebridge: ^0.0.1
```

Or run:

```bash
flutter pub add firebridge
```

---

## Quick Start

### 1. Initialize Firebridge in `main()`

```dart
import 'package:flutter/material.dart';
import 'package:firebridge/firebridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebridge.initialize(
    enableLogging: true, // Toggle detailed runtime logs
    webClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com', // Required for Web
    defaultRegion: 'nam5', // Default Firestore region
  );

  runApp(const MyApp());
}
```

### 2. Authenticate the User

```dart
// 1-Tap Google Sign-In with delegated Cloud and Firebase scopes
final user = await Firebridge.auth.signIn();

// Or developer direct token sign-in (useful for testing):
await Firebridge.auth.signInWithToken('ya29.a0AfH6...');
```

### 3. Drop in the Project Picker Widget

Use `FirebridgeProjectPicker` anywhere in your widget tree:

```dart
FirebridgeProjectPicker(
  onProjectSelected: (FirebridgeProject project) {
    print('Connected to user cloud: ${project.projectId}');
    // Navigate to your main application screen
  },
)
```

### 4. Perform Fluent Firestore CRUD Operations

Access the user's isolated Firestore database with the fluent `Firebridge.use()` syntax:

```dart
// Bind to the selected project
final app = Firebridge.use('user-project-id');

// Reference collection
final collection = app.firestore.collection('notes');

// 1. Read documents
List<FirebridgeDocument> docs = await collection.get();
for (var doc in docs) {
  print('Note: ${doc['title']} created by ${doc.createdBy}');
}

// 2. Add document (auto-populates server UTC timestamp)
FirebridgeDocument newDoc = await collection.add({
  'title': 'My Secret Note',
  'content': 'Saved directly in my own Google Cloud project!',
  'isEncrypted': true,
});

// 3. Update document with merge
await collection.doc(newDoc.id).set({
  'content': 'Updated private note content.',
}, merge: true);

// 4. Delete document
await collection.doc(newDoc.id).delete();
```

---

## Actionable Error Diagnostics

Firebridge catches Google Cloud API issues and translates them into actionable `FirebridgeException` instances.

When an API is disabled or permissions are missing, show the built-in dialog:

```dart
try {
  await Firebridge.projects.list();
} on FirebridgeException catch (e) {
  FirebridgeErrorDialog.show(context, error: e);
}
```

The dialog displays:
1. **Error Code**: e.g., `FB_API_NOT_ENABLED`
2. **What Happened**: Clear human explanation
3. **How to Resolve**: Step-by-step fix
4. **Button**: "Open Google Cloud Console" opening directly to the toggle page.

---

## Documentation & Guides

- 📖 **Complete Developer Guide**: See [USAGE.md](USAGE.md) for detailed configuration, OAuth setup, and API tutorials.
- 🛠️ **Error Catalog & Troubleshooting**: See [ERRORS.md](ERRORS.md) for all error codes, causes, and step-by-step resolution guides.
- 💻 **Runnable Example App**: Check out the [example](example) directory for a fully functioning sample app.

---

## Error Codes Catalog

| Error Code | Meaning |
|---|---|
| `FB_API_NOT_ENABLED` | Required Google Cloud API is disabled on the project. Direct enable link provided. |
| `FB_PERMISSION_DENIED` | Account lacks Owner/Editor IAM permissions on the project. |
| `FB_WEB_CLIENT_ID_MISSING` | Web platform invoked without a configured OAuth Web Client ID. |
| `FB_AUTH_CANCELLED` | User aborted the Google Sign-In prompt. |
| `FB_AUTH_TOKEN_EXPIRED` | Access token expired and could not be refreshed. |
| `FB_QUOTA_EXCEEDED` | Google Cloud project creation quota exceeded for the user's account. |
| `FB_BILLING_REQUIRED` | Selected API requires an active Google Cloud billing account. |
| `FB_PROJECT_COLLISION` | Project ID already taken globally. |
| `FB_PROPAGATION_TIMEOUT` | Google Cloud internal regional replication is taking longer than usual. |
| `FB_FIRESTORE_NOT_FOUND` | Database does not exist or has not been initialized. |

See [ERRORS.md](ERRORS.md) for full descriptions and resolution guides.

---

## Contributing & License

Contributions, bug reports, and pull requests are welcome on GitHub!
Released under the [MIT License](LICENSE).
