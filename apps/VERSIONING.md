# ClawDE Versioning

ClawDE follows semantic versioning (semver) independent of the nSelf CLI.

## Current Versions

| Component       | Version | Package file                                    |
|-----------------|---------|-------------------------------------------------|
| Desktop app     | 1.0.9   | apps/desktop/pubspec.yaml                       |
| Mobile app      | 1.0.9   | apps/mobile/pubspec.yaml                        |
| clawd daemon    | 1.0.9   | apps/daemon/Cargo.toml                          |
| clawd_client    | 1.0.9   | apps/packages/clawd_client/pubspec.yaml         |
| clawd_proto     | 1.0.9   | apps/packages/clawd_proto/pubspec.yaml          |

## Versioning Policy

Desktop + mobile + daemon MUST share the same version number in each release.
Package versions (clawd_client, clawd_proto) MAY lag by one minor version.

ClawDE does NOT track nSelf CLI versions. A ClawDE v1.2.0 release is independent
of whether nSelf CLI ships anything simultaneously.

## Release Cadence

- Patch (1.0.x): bug fixes, no API changes
- Minor (1.x.0): new features, backward-compatible API additions
- Major (x.0.0): breaking daemon API changes (IPC protocol version bump required)

## How to Release

1. Bump version in all 5 files listed above (must all match)
2. Update CHANGELOG.md (apps/CHANGELOG.md)
3. Run CI: `cd apps && melos run test`
4. Tag: `git tag clawde-v{version}` (NOT nself-v{version})
5. Push tag — GitHub Actions builds and publishes

ClawDE uses its own git tag prefix (`clawde-v`) to avoid conflicts with nSelf
CLI tags (`nself-v`).
