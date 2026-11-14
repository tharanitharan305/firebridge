import 'package:flutter/material.dart';

import '../../firebridge.dart';

/// Drop-in Material 3 project selection & provisioning widget.
class FirebridgeProjectPicker extends StatefulWidget {
  /// Callback triggered when the user picks or provisions an active project.
  final void Function(FirebridgeProject project) onProjectSelected;

  /// Optional custom header widget rendered above the project list.
  final Widget? header;

  /// Default Firestore region for newly provisioned projects (defaults to 'nam5').
  final String defaultRegion;

  const FirebridgeProjectPicker({
    super.key,
    required this.onProjectSelected,
    this.header,
    this.defaultRegion = 'nam5',
  });

  @override
  State<FirebridgeProjectPicker> createState() => _FirebridgeProjectPickerState();
}

class _FirebridgeProjectPickerState extends State<FirebridgeProjectPicker> {
  List<FirebridgeProject> _projects = [];
  bool _isLoading = true;
  FirebridgeException? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await Firebridge.projects.list();
      if (mounted) {
        setState(() {
          _projects = list;
          _isLoading = false;
        });
      }
    } on FirebridgeException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = FirebridgeException(
            code: FirebridgeErrorCodes.networkError,
            message: 'Failed to load projects: $e',
            details: e,
          );
          _isLoading = false;
        });
      }
    }
  }

  void _showProvisionDialog() {
    final nameController = TextEditingController(text: 'My Private Cloud');
    final idController = TextEditingController(
      text: FirebridgeProvisioningEngine.generateUniqueProjectId(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ProvisionProgressDialog(
        initialName: nameController.text,
        initialId: idController.text,
        defaultRegion: widget.defaultRegion,
        onSuccess: (newProject) {
          Navigator.of(dialogCtx).pop();
          widget.onProjectSelected(newProject);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = Firebridge.auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,

        // User Account Card
        if (user != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage:
                      user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null
                      ? Text(user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () async {
                    await Firebridge.auth.signOut();
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),

        // Action Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Google Cloud Projects',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.icon(
                onPressed: _showProvisionDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Project'),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: Builder(
            builder: (context) {
              if (_isLoading) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Discovering cloud projects...'),
                    ],
                  ),
                );
              }

              if (_error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text(
                          'Project Discovery Failed',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!.message,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => FirebridgeErrorDialog.show(
                                context,
                                error: _error!,
                                onRetry: _loadProjects,
                              ),
                              icon: const Icon(Icons.info_outline_rounded, size: 18),
                              label: const Text('View Resolution'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _loadProjects,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_projects.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 48, color: colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No Google Cloud Projects Found',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click "New Project" to provision an isolated Firebase instance automatically.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _showProvisionDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Provision New Project'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final project = _projects[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: project.isFirebaseEnabled
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        child: Icon(
                          project.isFirebaseEnabled
                              ? Icons.local_fire_department_rounded
                              : Icons.cloud_outlined,
                          color: project.isFirebaseEnabled
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        project.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.projectId,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              _Badge(
                                label: project.isFirebaseEnabled
                                    ? 'Firebase Active'
                                    : 'Cloud Only',
                                isPrimary: project.isFirebaseEnabled,
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => widget.onProjectSelected(project),
                        child: const Text('Select'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _Badge({required this.label, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isPrimary
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ProvisionProgressDialog extends StatefulWidget {
  final String initialName;
  final String initialId;
  final String defaultRegion;
  final void Function(FirebridgeProject project) onSuccess;

  const _ProvisionProgressDialog({
    required this.initialName,
    required this.initialId,
    required this.defaultRegion,
    required this.onSuccess,
  });

  @override
  State<_ProvisionProgressDialog> createState() => _ProvisionProgressDialogState();
}

class _ProvisionProgressDialogState extends State<_ProvisionProgressDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _idController;

  bool _isProvisioning = false;
  String _currentStep = '';
  double _progressPercent = 0.0;
  FirebridgeException? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _idController = TextEditingController(text: widget.initialId);
  }

  Future<void> _startProvisioning() async {
    setState(() {
      _isProvisioning = true;
      _error = null;
    });

    try {
      final project = await Firebridge.projects.create(
        name: _nameController.text.trim(),
        projectId: _idController.text.trim(),
        location: widget.defaultRegion,
        onProgress: (step, message) {
          if (mounted) {
            setState(() {
              _currentStep = message;
              if (step == ProvisioningStep.generatingId.name) _progressPercent = 0.1;
              if (step == ProvisioningStep.creatingProject.name) _progressPercent = 0.3;
              if (step == ProvisioningStep.enablingApis.name) _progressPercent = 0.55;
              if (step == ProvisioningStep.addingFirebase.name) _progressPercent = 0.75;
              if (step == ProvisioningStep.creatingFirestore.name) _progressPercent = 0.9;
              if (step == ProvisioningStep.verifying.name) _progressPercent = 0.98;
            });
          }
        },
      );

      if (mounted) {
        widget.onSuccess(project);
      }
    } on FirebridgeException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isProvisioning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = FirebridgeException(
            code: FirebridgeErrorCodes.networkError,
            message: 'Provisioning failed: $e',
            details: e,
          );
          _isProvisioning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isProvisioning) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Provisioning Your Cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: _progressPercent > 0 ? _progressPercent : null),
            const SizedBox(height: 16),
            Text(
              _currentStep.isNotEmpty ? _currentStep : 'Initializing pipeline...',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Enabling Firestore & Firebase instances directly in your Google account.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return FirebridgeErrorDialog(
        error: _error!,
        onRetry: _startProvisioning,
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Provision New BYOC Project'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A dedicated Google Cloud project and Native Firestore database will be created directly under your Google account.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Google Cloud Project ID',
                helperText: '6-30 characters, lowercase letters, numbers, and hyphens.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _startProvisioning,
          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
          label: const Text('Provision Cloud'),
        ),
      ],
    );
  }
}

