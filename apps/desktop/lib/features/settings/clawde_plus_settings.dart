// ClawDE+ section of Settings — license status, sync toggle, team management.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clawd_core/clawd_core.dart';
import 'package:clawd_ui/clawd_ui.dart';

/// Tracks whether server sync is enabled. Initialized to false; updated via
/// the `sync.setEnabled` RPC.
final syncEnabledProvider = StateProvider<bool>((ref) => false);

/// Tracks whether shared sessions is enabled. Initialized to false; updated
/// via the `team.setSharedSessions` RPC.
final sharedSessionsEnabledProvider = StateProvider<bool>((ref) => false);

/// Reads the last sync timestamp from daemon status if available.
///
/// Returns a human-readable string such as "Never synced" or a formatted
/// date/time when the `syncLastAt` field is present in the daemon info.
final syncLastAtProvider = Provider<String>((ref) {
  // daemonInfo does not currently expose syncLastAt; fall back gracefully.
  return 'Never synced';
});

/// ClawDE+ settings panel — license status, server sync, and team features.
class ClawdePlusSettings extends ConsumerWidget {
  const ClawdePlusSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseAsync = ref.watch(licenseProvider);
    final syncEnabled = ref.watch(syncEnabledProvider);
    final sharedSessionsEnabled = ref.watch(sharedSessionsEnabledProvider);
    final lastSync = ref.watch(syncLastAtProvider);

    return licenseAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading license: $e'),
      data: (license) {
        final isActive = license.tier != 'free';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              title: 'ClawDE+',
              subtitle: 'Subscription status, cloud sync, and team features',
            ),
            const SizedBox(height: 24),

            // ── License status card ──────────────────────────────────────────
            _LicenseCard(isActive: isActive, tier: license.tier),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── Server sync toggle ───────────────────────────────────────────
            const _SectionLabel('Server Sync'),
            const SizedBox(height: 12),
            _SyncToggle(
              isActive: isActive,
              enabled: syncEnabled,
              lastSync: lastSync,
              onChanged: isActive
                  ? (v) => _setSyncEnabled(ref, v)
                  : null,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── Team features ────────────────────────────────────────────────
            const _SectionLabel('Team Features'),
            const SizedBox(height: 12),
            _TeamSection(
              isActive: isActive,
              sharedSessionsEnabled: sharedSessionsEnabled,
              onSharedSessionsChanged: isActive
                  ? (v) => _setSharedSessions(ref, v)
                  : null,
            ),
          ],
        );
      },
    );
  }

  Future<void> _setSyncEnabled(WidgetRef ref, bool value) async {
    ref.read(syncEnabledProvider.notifier).state = value;
    final daemon = ref.read(daemonProvider);
    if (!daemon.isConnected) return;
    try {
      final client = ref.read(daemonProvider.notifier).client;
      await client.call<void>('sync.setEnabled', {'enabled': value});
    } catch (_) {
      // Revert on failure.
      ref.read(syncEnabledProvider.notifier).state = !value;
    }
  }

  Future<void> _setSharedSessions(WidgetRef ref, bool value) async {
    ref.read(sharedSessionsEnabledProvider.notifier).state = value;
    final daemon = ref.read(daemonProvider);
    if (!daemon.isConnected) return;
    try {
      final client = ref.read(daemonProvider.notifier).client;
      await client.call<void>('team.setSharedSessions', {'enabled': value});
    } catch (_) {
      // Revert on failure.
      ref.read(sharedSessionsEnabledProvider.notifier).state = !value;
    }
  }
}

// ── License card ──────────────────────────────────────────────────────────────

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.isActive, required this.tier});

  final bool isActive;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final badgeColor = isActive ? Colors.green : Colors.white38;
    final badgeBg = isActive
        ? Colors.green.withValues(alpha: 0.12)
        : ClawdTheme.surfaceBorder.withValues(alpha: 0.4);
    final displayTier = tier == 'free' ? 'Inactive' : tier;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClawdTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? Colors.green.withValues(alpha: 0.3)
              : ClawdTheme.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withValues(alpha: 0.12)
                  : ClawdTheme.surfaceBorder.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              size: 20,
              color: isActive ? Colors.green : Colors.white38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isActive ? 'ClawDE+ Active' : 'ClawDE+ Inactive',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.green : Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: badgeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        displayTier,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Cloud sync and team features are available.'
                      : 'Upgrade to enable sync and team features.',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          if (!isActive)
            FilledButton(
              onPressed: () => launchUrl(
                Uri.parse('https://nself.org/clawde/plus'),
                mode: LaunchMode.externalApplication,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: ClawdTheme.claw,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              child: const Text(
                'Upgrade to ClawDE+',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sync toggle ───────────────────────────────────────────────────────────────

class _SyncToggle extends StatelessWidget {
  const _SyncToggle({
    required this.isActive,
    required this.enabled,
    required this.lastSync,
    this.onChanged,
  });

  final bool isActive;
  final bool enabled;
  final String lastSync;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ClawdTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ClawdTheme.surfaceBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sync session state',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Syncs session state to ClawDE cloud for mobile access',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last sync: $lastSync',
                    style: const TextStyle(fontSize: 10, color: Colors.white24),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onChanged,
              activeColor: ClawdTheme.claw,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Team section ──────────────────────────────────────────────────────────────

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.isActive,
    required this.sharedSessionsEnabled,
    this.onSharedSessionsChanged,
  });

  final bool isActive;
  final bool sharedSessionsEnabled;
  final ValueChanged<bool>? onSharedSessionsChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: ClawdTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ClawdTheme.surfaceBorder),
        ),
        child: Column(
          children: [
            // Team Members tile
            InkWell(
              onTap: isActive
                  ? () => context.push('/settings/team')
                  : null,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.group_outlined,
                        size: 18, color: Colors.white54),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Team Members',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage who has access to your ClawDE workspace',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 16, color: Colors.white38),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Shared Sessions toggle
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.screen_share_outlined,
                      size: 18, color: Colors.white54),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shared Sessions',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Allow team members to view and join your active sessions',
                          style:
                              TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: sharedSessionsEnabled,
                    onChanged: onSharedSessionsChanged,
                    activeColor: ClawdTheme.claw,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }
}
