import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clawd_core/clawd_core.dart';
import 'package:clawde_mobile/features/hosts/host_provider.dart';

/// The ClawDE backend base URL — reads session snapshots synced by the daemon.
const _kApiBase = 'https://api.clawde.io';

/// A session snapshot retrieved from the ClawDE sync API.
///
/// Mirrors the `SessionSyncEntry` pushed by the daemon every 30 seconds when
/// `license.features.clawde_plus == true`.
class RemoteSessionEntry {
  const RemoteSessionEntry({
    required this.id,
    required this.title,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String title;

  /// Session lifecycle status: 'running', 'paused', 'completed', 'error', etc.
  final String status;

  /// ISO-8601 timestamp of the last daemon sync for this session.
  final String updatedAt;

  factory RemoteSessionEntry.fromJson(Map<String, dynamic> json) =>
      RemoteSessionEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        updatedAt: json['updatedAt'] as String,
      );

  /// Parsed [updatedAt] as a [DateTime], or epoch on parse failure.
  DateTime get updatedAtDateTime =>
      DateTime.tryParse(updatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

// ─── State ────────────────────────────────────────────────────────────────────

/// State managed by [RemoteSessionsNotifier].
class RemoteSessionsState {
  const RemoteSessionsState({
    this.sessions = const [],
    this.isLoading = false,
    this.error,
    this.subscriptionRequired = false,
  });

  final List<RemoteSessionEntry> sessions;
  final bool isLoading;

  /// Non-null on network errors (other than 401/403).
  final String? error;

  /// True when the server returned 401 or 403 — prompt user to upgrade.
  final bool subscriptionRequired;

  RemoteSessionsState copyWith({
    List<RemoteSessionEntry>? sessions,
    bool? isLoading,
    String? error,
    bool? subscriptionRequired,
  }) =>
      RemoteSessionsState(
        sessions: sessions ?? this.sessions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        subscriptionRequired: subscriptionRequired ?? this.subscriptionRequired,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Polls `GET {api}/sync/sessions?daemonId={daemonId}` every 60 seconds while
/// the active host has `clawde_plus` enabled (read from `license.get`).
///
/// Returns a sorted (newest-first) list of [RemoteSessionEntry] items.
/// Falls back to cached sessions when offline; clears state on 401/403.
class RemoteSessionsNotifier extends Notifier<RemoteSessionsState> {
  Timer? _pollTimer;

  @override
  RemoteSessionsState build() {
    ref.onDispose(_cancelPoll);

    // Re-evaluate whenever daemon connection or active host changes.
    ref.listen(daemonProvider, (_, __) => _checkLicenseAndMaybePoll());
    ref.listen(activeHostIdProvider, (_, __) => _checkLicenseAndMaybePoll());

    _checkLicenseAndMaybePoll();
    return const RemoteSessionsState();
  }

  // ─── License gate ─────────────────────────────────────────────────────────

  Future<void> _checkLicenseAndMaybePoll() async {
    final daemon = ref.read(daemonProvider);
    if (!daemon.isConnected) {
      _cancelPoll();
      return;
    }

    bool clawdePlus = false;
    try {
      final client = ref.read(daemonProvider.notifier).client;
      final result = await client.call<Map<String, dynamic>>('license.get');
      final features = result['features'] as Map<String, dynamic>? ?? {};
      clawdePlus = features['clawdePlus'] as bool? ?? false;
    } catch (_) {
      clawdePlus = false;
    }

    if (!clawdePlus) {
      _cancelPoll();
      state = const RemoteSessionsState();
      return;
    }

    // Start the 60s poll timer if not already running.
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetch(),
    );

    // Fetch immediately on first activation or host change.
    await _fetch();
  }

  void _cancelPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    // Resolve active host for daemonId and bearer token.
    final activeId = ref.read(activeHostIdProvider);
    final hosts = ref.read(hostListProvider).valueOrNull ?? [];
    final host = activeId != null
        ? hosts.where((h) => h.id == activeId).firstOrNull
        : null;

    if (host == null) return;

    final daemonId = host.daemonId;
    if (daemonId == null || daemonId.isEmpty) return;

    // The pairing token (device trust token) is used as the Bearer credential.
    final bearerToken = host.pairingToken;
    if (bearerToken == null || bearerToken.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final uri = Uri.parse('$_kApiBase/sync/sessions')
          .replace(queryParameters: {'daemonId': daemonId});

      final httpClient = HttpClient();
      try {
        httpClient.connectionTimeout = const Duration(seconds: 10);
        final request = await httpClient.getUrl(uri);
        request.headers.set('Authorization', 'Bearer $bearerToken');
        request.headers.set('Accept', 'application/json');
        final response = await request.close();

        if (response.statusCode == 401 || response.statusCode == 403) {
          // Subscription lapsed or token revoked.
          await response.drain<void>();
          state = const RemoteSessionsState(
            subscriptionRequired: true,
            isLoading: false,
          );
          _cancelPoll();
          return;
        }

        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          // Non-auth server error — keep cached sessions, surface error.
          state = state.copyWith(
            isLoading: false,
            error: 'Server error ${response.statusCode}',
          );
          return;
        }

        final decoded = jsonDecode(body);
        final List<dynamic> rawList;
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded.containsKey('sessions')) {
          rawList = decoded['sessions'] as List<dynamic>;
        } else {
          rawList = const [];
        }

        final entries = rawList
            .map((e) => RemoteSessionEntry.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.updatedAtDateTime.compareTo(a.updatedAtDateTime));

        state = RemoteSessionsState(sessions: entries, isLoading: false);
      } finally {
        httpClient.close();
      }
    } on SocketException {
      // Offline — retain cached sessions, no visible error for transient blips.
      state = state.copyWith(isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load sessions',
      );
    }
  }

  /// Manually trigger a refresh — called by the Retry button in the UI.
  Future<void> refresh() => _fetch();
}

final remoteSessionsProvider =
    NotifierProvider<RemoteSessionsNotifier, RemoteSessionsState>(
  RemoteSessionsNotifier.new,
);
