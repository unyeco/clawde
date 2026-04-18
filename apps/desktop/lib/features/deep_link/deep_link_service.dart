// deep_link_service.dart — Deep link handling for ClawDE desktop.
//
// Scheme: clawde://
// Supported URIs:
//   clawde://session/{id}           → navigate to session detail
//   clawde://file?path={abs_path}   → open file in editor (FilesScreen)
//   clawde://folder?path={abs_path} → open folder as root in FilesScreen
//   clawde://command?name={name}    → execute a named command
//
// Named commands:
//   new_session  → push /chat (triggers new session flow)
//   search       → push /search
//   settings     → push /settings
//
// On macOS deep links arrive via NSApplicationDelegate openURLs.
// The `app_links` package surfaces them as a Dart stream on all desktop platforms.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

// ─── Deep link target types ───────────────────────────────────────────────────

sealed class DeepLinkTarget {
  const DeepLinkTarget();
}

class SessionTarget extends DeepLinkTarget {
  const SessionTarget(this.sessionId);
  final String sessionId;
}

class FileTarget extends DeepLinkTarget {
  const FileTarget(this.path);
  final String path;
}

class FolderTarget extends DeepLinkTarget {
  const FolderTarget(this.path);
  final String path;
}

class CommandTarget extends DeepLinkTarget {
  const CommandTarget(this.name);
  final String name;
}

// ─── Parser ───────────────────────────────────────────────────────────────────

/// Parse a [uri] into a [DeepLinkTarget]. Returns null for unrecognised URIs.
///
/// Supported forms:
///   clawde://session/abc123
///   clawde://file?path=/absolute/path/to/file.dart
///   clawde://folder?path=/absolute/path/to/dir
///   clawde://command?name=new_session
DeepLinkTarget? parseDesktopDeepLink(Uri uri) {
  if (uri.scheme != 'clawde') return null;

  // The URI host carries the "type" for authority-style URIs
  // (e.g. clawde://session/abc123 → host = "session").
  // Query-param style URIs share the same host field.
  final type = uri.host;

  switch (type) {
    case 'session':
      final segments = uri.pathSegments;
      if (segments.isEmpty) return null;
      return SessionTarget(segments.first);

    case 'file':
      final path = uri.queryParameters['path'];
      if (path == null || path.isEmpty) return null;
      return FileTarget(path);

    case 'folder':
      final path = uri.queryParameters['path'];
      if (path == null || path.isEmpty) return null;
      return FolderTarget(path);

    case 'command':
      final name = uri.queryParameters['name'];
      if (name == null || name.isEmpty) return null;
      return CommandTarget(name);

    default:
      return null;
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class DesktopDeepLinkService {
  DesktopDeepLinkService({required GoRouter router}) : _router = router;

  final GoRouter _router;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Start listening for incoming deep links.
  ///
  /// Handles both cold-start links (app opened by URL) and warm-start links
  /// (URL received while app is already running).
  Future<void> start() async {
    // Cold start: link that launched the app.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _navigate(initial);
    } catch (e) {
      debugPrint('[DesktopDeepLinkService] initial link error: $e');
    }

    // Warm start: links received while the app is running.
    _sub = _appLinks.uriLinkStream.listen(
      _navigate,
      onError: (e) => debugPrint('[DesktopDeepLinkService] link stream error: $e'),
    );
  }

  void _navigate(Uri uri) {
    final target = parseDesktopDeepLink(uri);
    if (target == null) {
      debugPrint('[DesktopDeepLinkService] unrecognised link: $uri');
      return;
    }

    switch (target) {
      case SessionTarget(:final sessionId):
        _router.push('/sessions/$sessionId');

      case FileTarget(:final path):
        _router.push('/files?path=${Uri.encodeComponent(path)}');

      case FolderTarget(:final path):
        _router.push('/files?folder=${Uri.encodeComponent(path)}');

      case CommandTarget(:final name):
        switch (name) {
          case 'new_session':
            _router.push('/chat');
          case 'search':
            _router.push('/search');
          case 'settings':
            _router.push('/settings');
          default:
            debugPrint('[DesktopDeepLinkService] unknown command: $name');
        }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
