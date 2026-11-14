import 'package:flutter/foundation.dart';

/// Internal sanitized logger for the Firebridge package.
/// Respects the global `enableLogging` configuration.
class FirebridgeLogger {
  /// Global logging gate.
  static bool enabled = false;

  const FirebridgeLogger();

  /// Logs a debug-level message if logging is enabled.
  static void d(String message, [String? tag]) {
    if (!enabled) return;
    _print('DEBUG', tag, sanitize(message));
  }

  /// Logs an info-level message if logging is enabled.
  static void i(String message, [String? tag]) {
    if (!enabled) return;
    _print('INFO', tag, sanitize(message));
  }

  /// Logs a warning-level message if logging is enabled.
  static void w(String message, [String? tag]) {
    if (!enabled) return;
    _print('WARN', tag, sanitize(message));
  }

  /// Logs an error-level message if logging is enabled.
  static void e(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    if (!enabled) return;
    _print('ERROR', tag, sanitize(message));
    if (error != null) {
      debugPrint('   [Details]: ${sanitize(error.toString())}');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('   [StackTrace]: $stackTrace');
    }
  }

  /// Redacts Bearer tokens, API keys, or long credential hashes.
  static String sanitize(String text) {
    return text
        .replaceAll(RegExp(r'(Bearer\s+)[A-Za-z0-9_\-\.]{15,}'), r'$1[REDACTED_TOKEN]')
        .replaceAll(RegExp(r'(key=)[A-Za-z0-9_\-]{20,}'), r'$1[REDACTED_KEY]')
        .replaceAll(RegExp(r'(client_secret=)[A-Za-z0-9_\-]{15,}'), r'$1[REDACTED_SECRET]');
  }

  static void _print(String level, String? tag, String text) {
    final prefix = tag != null ? '[Firebridge:$tag]' : '[Firebridge]';
    debugPrint('$prefix [$level] $text');
  }
}
