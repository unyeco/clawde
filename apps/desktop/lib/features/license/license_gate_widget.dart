// Conditional widget that renders [child] when ClawDE+ is active, or an
// upgrade prompt card when it is not.
//
// Usage:
//   ClawdePlusGate(
//     featureName: 'Team Features',
//     child: TeamFeaturesPanel(),
//   )

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clawd_core/clawd_core.dart';
import 'package:clawd_ui/clawd_ui.dart';

/// Shows [child] when ClawDE+ is active on the connected daemon's license.
/// Shows [_UpgradePromptCard] when ClawDE+ is not active.
///
/// The gate reads from [licenseProvider] — the same provider used by
/// [ClawdePlusSettings] — so the displayed state is always consistent with
/// the rest of the app.
class ClawdePlusGate extends ConsumerWidget {
  const ClawdePlusGate({
    super.key,
    required this.child,
    this.featureName = 'This feature',
  });

  /// The widget to display when ClawDE+ is active.
  final Widget child;

  /// Human-readable name shown in the upgrade prompt, e.g. "Team Features".
  final String featureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseAsync = ref.watch(licenseProvider);

    return licenseAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _UpgradePromptCard(featureName: featureName),
      data: (license) {
        if (license.clawdePlus) {
          return child;
        }
        return _UpgradePromptCard(featureName: featureName);
      },
    );
  }
}

// ── Upgrade prompt card ───────────────────────────────────────────────────────

/// Displayed by [ClawdePlusGate] when ClawDE+ is not active.
///
/// Shows the feature name, a brief explanation, and a CTA button that opens
/// the ClawDE+ purchase page.
class _UpgradePromptCard extends StatelessWidget {
  const _UpgradePromptCard({required this.featureName});

  final String featureName;

  static const _upgradeUrl = 'https://nself.org/clawde/plus';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClawdTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ClawdTheme.claw.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ClawdTheme.claw.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 18,
                  color: ClawdTheme.clawLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ClawDE+ Required',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$featureName requires ClawDE+.',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upgrade to unlock cloud sync, team features, and more.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white38,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => launchUrl(
              Uri.parse(_upgradeUrl),
              mode: LaunchMode.externalApplication,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ClawdTheme.claw,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Get ClawDE+ for \$1.99/mo',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
