// Team members management page — lists team members via `team.listMembers` RPC.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clawd_core/clawd_core.dart';
import 'package:clawd_ui/clawd_ui.dart';

/// Fetches the list of team members from the daemon via `team.listMembers`.
///
/// Returns an empty list when the daemon is not connected or the call fails.
final teamMembersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final daemon = ref.watch(daemonProvider);
  if (!daemon.isConnected) return [];

  try {
    final client = ref.read(daemonProvider.notifier).client;
    final result = await client.call<dynamic>('team.listMembers', {});
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (_) {
    return [];
  }
});

/// Page that lists team members for the ClawDE+ workspace.
class TeamMembersPage extends ConsumerWidget {
  const TeamMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      backgroundColor: ClawdTheme.surface,
      appBar: AppBar(
        backgroundColor: ClawdTheme.surfaceElevated,
        elevation: 0,
        title: const Text(
          'Team Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: ClawdTheme.surfaceBorder),
        ),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load team members: $e',
            style: const TextStyle(fontSize: 13, color: ClawdTheme.error),
          ),
        ),
        data: (members) => members.isEmpty
            ? _EmptyState()
            : _MembersList(members: members),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ClawdTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClawdTheme.surfaceBorder),
            ),
            child: const Icon(
              Icons.group_outlined,
              size: 28,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No team members yet',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white54),
          ),
          const SizedBox(height: 6),
          const Text(
            'No team members yet — invite via ClawDE+ dashboard.',
            style: TextStyle(fontSize: 12, color: Colors.white24),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Members list ──────────────────────────────────────────────────────────────

class _MembersList extends StatelessWidget {
  const _MembersList({required this.members});

  final List<Map<String, dynamic>> members;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _MemberTile(member: members[i]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    final name = member['name'] as String? ?? 'Unknown';
    final email = member['email'] as String? ?? '';
    final role = member['role'] as String? ?? 'member';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ClawdTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ClawdTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ClawdTheme.claw.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ClawdTheme.clawLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                ],
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ClawdTheme.surfaceBorder.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClawdTheme.surfaceBorder),
            ),
            child: Text(
              role,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
