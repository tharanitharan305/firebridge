import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/errors.dart';

/// Actionable Material 3 dialog presenting a [FirebridgeException] with resolution steps and direct Cloud Console links.
class FirebridgeErrorDialog extends StatelessWidget {
  final FirebridgeException error;
  final VoidCallback? onRetry;

  const FirebridgeErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
  });

  /// Displays the [FirebridgeErrorDialog] as a modal.
  static Future<void> show(
    BuildContext context, {
    required FirebridgeException error,
    VoidCallback? onRetry,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => FirebridgeErrorDialog(
        error: error,
        onRetry: onRetry,
      ),
    );
  }

  Future<void> _launchHelpUrl() async {
    if (error.helpUrl == null) return;
    final uri = Uri.tryParse(error.helpUrl!);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Configuration Error',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Code Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                error.code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              error.message,
              style: theme.textTheme.bodyMedium,
            ),

            // Resolution Steps Card
            if (error.resolutionSteps != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'How to resolve:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.resolutionSteps!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Help URL Action
            if (error.helpUrl != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _launchHelpUrl,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open Google Cloud Console'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dismiss'),
        ),
        if (onRetry != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
      ],
    );
  }
}

