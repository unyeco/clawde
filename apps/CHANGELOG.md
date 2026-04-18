# ClawDE Changelog

All notable changes to ClawDE are documented here.
Follows [Keep a Changelog](https://keepachangelog.com/) format.

## [1.0.9] - 2026-04-18

### Added
- Global hotkey (⌘⇧Space / Ctrl+Shift+Space) to toggle window visibility
- Round-robin account selection within priority tiers (avoids repeated rate-limit hits on same account)
- ClawDE+ bundle wiring: server-sync to `ping.nself.org` (license validated internally, not via plugin store)
- Mobile twin sync: session state accessible from iOS/Android companion app
- Batch file op delivery on reconnect: buffered ops replay when client reconnects
- License check and feature gate for ClawDE+ tier
- ClawDE+ section in Settings: license status, sync toggle, team management
- Deep links: `clawde://file`, `clawde://folder`, `clawde://command`, `clawde://session`
- Version lineage documentation (VERSIONING.md, CHANGELOG.md)

### Changed
- Tray menu now shows idle state when no sessions are open
- Multi-account pool uses round-robin within priority tiers

## [1.0.8] - 2026-03-28

### Changed
- Repository transferred from unyeco-org to nself-org
