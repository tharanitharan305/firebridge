# Firebridge Error Catalog & Troubleshooting Guide 🛠️

Every exception thrown by Firebridge is an instance of `FirebridgeException`. Each exception includes:

- `code`: Machine-readable unique error string (e.g. `FB_API_NOT_ENABLED`).
- `message`: Clear, human-readable summary of what failed.
- `resolutionSteps`: Actionable, step-by-step instructions to fix the error.
- `helpUrl`: Direct clickable link to the relevant Google Cloud Console or Firebase Console page.
- `details`: Underlying raw HTTP response, error code, or stack trace.

---

## 1. Quick Reference Table

| Error Code | Category | Root Cause | Direct Fix |
|---|---|---|---|
| `FB_API_NOT_ENABLED` | GCP API | Required Google Cloud API is disabled on project | Open GCP Console and enable the API |
| `FB_PERMISSION_DENIED` | IAM Permissions | User Google account lacks Owner/Editor role on project | Grant Owner role or create a new project |
| `FB_WEB_CLIENT_ID_MISSING` | Authentication | Web platform invoked without `webClientId` set | Pass `webClientId` to `Firebridge.initialize()` |
| `FB_AUTH_CANCELLED` | Authentication | User dismissed or closed the Google Sign-In prompt | Retry sign-in flow |
| `FB_AUTH_TOKEN_EXPIRED` | Authentication | OAuth token expired and cannot be refreshed silently | Re-authenticate user via `signIn()` |
| `FB_UNAUTHENTICATED` | Authentication | Operation called before signing in | Call `Firebridge.auth.signIn()` first |
| `FB_AUTH_FAILED` | Authentication | OAuth consent screen or SHA-1 fingerprint mismatch | Verify SHA-1 & package name in GCP Console |
| `FB_QUOTA_EXCEEDED` | GCP Quotas | User account reached maximum project creation quota | Select existing project or request quota |
| `FB_BILLING_REQUIRED` | Billing | Selected API or region requires linked billing account | Link billing account in GCP Console |
| `FB_PROJECT_COLLISION` | Provisioning | Generated GCP project ID already taken globally | System automatically generates new unique ID |
| `FB_PROPAGATION_TIMEOUT` | GCP Latency | Regional resource replication took > 30 seconds | Wait 30 seconds and retry connection |
| `FB_FIRESTORE_NOT_FOUND` | Firestore | Firestore database has not been initialized yet | Create database via Provisioning Engine |
| `FB_FIRESTORE_CREATE_FAILED` | Firestore | Database creation rejected by Google Cloud | Check project location and IAM permissions |
| `FB_NETWORK_ERROR` | Network | No internet connection or Google servers unreachable | Check network connectivity |

---

## 2. Detailed Error Explanations & Step-by-Step Fixes

### `FB_API_NOT_ENABLED`
- **What happened**: Your app attempted to make a call to an API that is currently disabled in the user's Google Cloud project (such as `cloudresourcemanager.googleapis.com`, `firestore.googleapis.com`, `firebase.googleapis.com`, or `serviceusage.googleapis.com`).
- **Common Google Error**: `403 PERMISSION_DENIED: Service has not been used in project X before or it is disabled.`
- **How to Resolve**:
  1. Click the provided `helpUrl` link or open [Google Cloud Console API Library](https://console.cloud.google.com/apis/library).
  2. Select the target project from the top dropdown.
  3. Search for the disabled API name shown in the error dialog.
  4. Click the blue **ENABLE** button.
  5. Wait 30–60 seconds for Google's internal servers to propagate the change, then retry.

---

### `FB_WEB_CLIENT_ID_MISSING`
- **What happened**: The app is running on Flutter Web, and `Firebridge.auth.signIn()` was invoked without specifying `webClientId`.
- **Why it occurs**: Unlike Android (which uses Google Play Services and SHA-1 fingerprints), Web browsers require an explicit OAuth 2.0 Web Client ID for Google Identity Services.
- **How to Resolve**:
  1. Open [Google Cloud Console Credentials](https://console.cloud.google.com/apis/credentials).
  2. Click **Create Credentials** > **OAuth client ID**.
  3. Select **Web application**.
  4. Under **Authorized JavaScript origins**, add your origin (e.g. `http://localhost:3000`).
  5. Pass the generated client ID to `Firebridge.initialize()`:
     ```dart
     await Firebridge.initialize(
       webClientId: 'xxx.apps.googleusercontent.com',
     );
     ```

---

### `FB_PERMISSION_DENIED`
- **What happened**: The authenticated Google account does not have sufficient IAM permissions to list, create, or modify resources in the selected Google Cloud project.
- **Common Google Error**: `403 PERMISSION_DENIED: The caller does not have permission.`
- **How to Resolve**:
  1. Open [Google Cloud Console IAM & Admin](https://console.cloud.google.com/iam-admin/iam).
  2. Select the project and verify your Google email address is listed.
  3. Ensure your account is assigned the **Owner** or **Editor** role, and the **Cloud Datastore User** role for Firestore access.
  4. If you do not own the project, use the **New Project** button in Firebridge to provision a project you own.

---

### `FB_QUOTA_EXCEEDED`
- **What happened**: The user's Google account has reached its maximum project creation quota (free accounts typically have a limit of 5–12 active projects).
- **Common Google Error**: `403 PERMISSION_DENIED: Project creation quota exceeded for your account.`
- **How to Resolve**:
  1. Open [Google Cloud Resource Manager](https://console.cloud.google.com/cloud-resource-manager).
  2. Delete unused or abandoned Google Cloud projects.
  3. Alternatively, select one of your existing active projects from the `FirebridgeProjectPicker` list instead of creating a new one.

---

### `FB_BILLING_REQUIRED`
- **What happened**: A requested service or region requires an active Google Cloud Billing account linked to the project.
- **Common Google Error**: `403 PERMISSION_DENIED: Billing account not configured.`
- **How to Resolve**:
  1. Open [Google Cloud Billing Console](https://console.cloud.google.com/billing).
  2. Link a billing account to the target project.
  3. Note: Cloud Firestore's free tier (1 GiB storage, 50,000 reads/day, 20,000 writes/day) requires zero payment, but certain advanced regions may require a linked billing profile.

---

### `FB_PROPAGATION_TIMEOUT`
- **What happened**: Newly enabled Google Cloud APIs or created Firestore databases take between 10 and 30 seconds to replicate internally across Google's regional infrastructure.
- **How to Resolve**:
  - Firebridge automatically retries requests 4 times with exponential backoff.
  - If a timeout occurs, wait 20–30 seconds and click **Try Again** in the UI.

---

## 3. Handling Errors in Your Code

Use `FirebridgeErrorDialog.show` to present beautiful, actionable resolution dialogs directly to your users:

```dart
try {
  final app = Firebridge.use(selectedProjectId);
  final docs = await app.firestore.collection('notes').get();
} on FirebridgeException catch (e) {
  // Shows error code, detailed explanation, and "Open Cloud Console" button
  FirebridgeErrorDialog.show(
    context,
    error: e,
    onRetry: () => loadNotes(),
  );
}
```
