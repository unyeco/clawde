import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clawd_ui/clawd_ui.dart';
import 'package:clawde_mobile/features/sync/remote_sessions_provider.dart';

/// Displays session snapshots synced from the daemon via the ClawDE+ API.
///
/// Only reachable when the active host has `clawde_plus` active.
/// Route: `/remote-sessions`
class RemoteSessionsScreen extends ConsumerWidget {
  const RemoteSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(remoteSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Sessions'),
        actions: [
          if (!syncState.subscriptionRequired)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: syncState.isLoading
                  ? null
                  : () => ref.read(remoteSessionsProvider.notifier).refresh(),
            ),
        ],
      ),
      body: _buildBody(context, ref, syncState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    RemoteSessionsState syncState,
  ) {
    // 401/403 — subscription prompt.
    if (syncState.subscriptionRequired) {
      return _SubscriptionRequiredState(
        onUpgrade: () => context.go('/settings'),
      );
    }

    // Loading with no cached data yet.
    if (syncState.isLoading && syncState.sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Non-auth error with no cached data.
    if (syncState.error != null && syncState.sessions.isEmpty) {
      return _ErrorState(
        onRetry: () => ref.read(remoteSessionsProvider.notifier).refresh(),
      );
    }

    // Empty — no sessions synced yet.
    if (syncState.sessions.isEmpty) {
      return const _EmptyState();
    }

    // Session list.
    return RefreshIndicator(
      onRefresh: () => ref.read(remoteSessionsProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: syncState.sessions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) {
          final session = syncState.sessions[i];
          return _SessionTile(
            session: session,
            onTap: () => context.go('/session/${session.id}'),
          );
        },
      ),
    );
  }
}

// ─── Session tile ─────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final RemoteSessionEntry session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _StatusIcon(status: session.status),
      title: Text(
        session.title.isNotEmpty ? session.title : 'Untitled Session',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatUpdatedAt(session.updatedAtDateTime),
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
      onTap: onTap,
    );
  }

  String _formatUpdatedAt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'updated just now';
    if (diff.inMinutes == 1) return 'updated 1 minute ago';
    if (diff.inMinutes < 60) return 'updated ${diff.inMinutes} minutes ago';
    if (diff.inHours == 1) return 'updated 1 hour ago';
    if (diff.inHours < 24) return 'updated ${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'updated 1 day ago';
    return 'updated ${diff.inDays} days ago';
  }
}

// ─── Status icon ──────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'running' => (Icons.play_circle_outline, ClawdTheme.success),
      'paused' => (Icons.pause_circle_outline, ClawdTheme.warning),
      'completed' => (Icons.check_circle_outline, Colors.white38),
      'error' => (Icons.error_outline, ClawdTheme.error),
      _ => (Icons.circle_outlined, Colors.white38),
    };
    return Icon(icon, color: color, size: 22);
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No active sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Start a session in ClawDE desktop',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Could not load sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Subscription required state ─────────────────────────────────────────────

class _SubscriptionRequiredState extends StatelessWidget {
  const _SubscriptionRequiredState({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'ClawDE+ subscription required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Remote session sync is a ClawDE+ feature.',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClawdTheme.claw,
                foregroundColor: Colors.white,
              ),
              child: const Text('Upgrade to ClawDE+'),
            ),
          ],
        ),
      ),
    );
  }
}
