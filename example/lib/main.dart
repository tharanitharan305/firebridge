import 'package:flutter/material.dart';
import 'package:firebridge/firebridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebridge BYOC Client
  await Firebridge.initialize(
    enableLogging: true,
    webClientId: '1027184333516-m3vvd76v3d7195p22q8600qllksu47v4.apps.googleusercontent.com',
    defaultRegion: 'nam5',
  );

  runApp(const FirebridgeExampleApp());
}

class FirebridgeExampleApp extends StatelessWidget {
  const FirebridgeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebridge BYOC Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF57C00),
          brightness: Brightness.light,
        ),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  FirebridgeProject? _selectedProject;

  @override
  Widget build(BuildContext context) {
    if (!Firebridge.auth.isSignedIn) {
      return AuthScreen(onSignedIn: () => setState(() {}));
    }

    if (_selectedProject == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Firebridge Cloud Selector'),
        ),
        body: FirebridgeProjectPicker(
          onProjectSelected: (project) {
            setState(() {
              _selectedProject = project;
            });
          },
        ),
      );
    }

    return ProjectDashboardScreen(
      project: _selectedProject!,
      onSwitchProject: () {
        setState(() {
          _selectedProject = null;
        });
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  final VoidCallback onSignedIn;

  const AuthScreen({super.key, required this.onSignedIn});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await Firebridge.auth.signIn();
      if (user != null) {
        widget.onSignedIn();
      }
    } on FirebridgeException catch (e) {
      if (mounted) {
        FirebridgeErrorDialog.show(context, error: e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDirectTokenDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Direct Token Sign-In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a valid OAuth2 Access Token (e.g. from `gcloud auth print-access-token`) to bypass OAuth consent screens during development.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Access Token',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final token = controller.text.trim();
              if (token.isEmpty) return;
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              try {
                await Firebridge.auth.signInWithToken(token);
                widget.onSignedIn();
              } on FirebridgeException catch (e) {
                if (mounted) FirebridgeErrorDialog.show(context, error: e);
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Authenticate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_rounded, size: 72, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Firebridge',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bring Your Own Cloud (BYOC) for Flutter',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 36),
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                FilledButton.icon(
                  onPressed: _handleGoogleSignIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Continue with Google'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(260, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showDirectTokenDialog,
                  icon: const Icon(Icons.vpn_key_rounded),
                  label: const Text('Direct Token Sign-In'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(260, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectDashboardScreen extends StatefulWidget {
  final FirebridgeProject project;
  final VoidCallback onSwitchProject;

  const ProjectDashboardScreen({
    super.key,
    required this.project,
    required this.onSwitchProject,
  });

  @override
  State<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends State<ProjectDashboardScreen> {
  late final FirebridgeApp _app;
  List<FirebridgeDocument> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _app = Firebridge.use(widget.project.projectId);
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _app.firestore.collection('notes').get();
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } on FirebridgeException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        FirebridgeErrorDialog.show(context, error: e, onRetry: _loadDocuments);
      }
    }
  }

  Future<void> _addDocument() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Private Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await _app.firestore.collection('notes').add({
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'author': Firebridge.auth.currentUser?.email ?? 'anonymous',
                });
                _loadDocuments();
              } on FirebridgeException catch (e) {
                if (mounted) FirebridgeErrorDialog.show(context, error: e);
              }
            },
            child: const Text('Save to My Cloud'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(String id) async {
    try {
      await _app.firestore.collection('notes').doc(id).delete();
      _loadDocuments();
    } on FirebridgeException catch (e) {
      if (mounted) FirebridgeErrorDialog.show(context, error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name, style: const TextStyle(fontSize: 16)),
            Text(
              widget.project.projectId,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch Project',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: widget.onSwitchProject,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(
                  child: Text('No notes stored yet. Tap + to add one!'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          doc.title ?? '(No Title)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(doc.content ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _deleteDocument(doc.id),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocument,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
