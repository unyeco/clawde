# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x (LTS) | Yes |
| < 1.0.0 | No |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email **security@clawde.io** (or use a GitHub Private Security Advisory) with:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (optional)

We will acknowledge receipt within 48 hours and provide a status update within 5 business days. Critical vulnerabilities are patched on a priority basis.

## Scope

In scope: ClawDE daemon, Flutter desktop and mobile apps, Dart packages (`clawd_client`, `clawd_proto`), authentication, JSON-RPC API surface.

Out of scope: Third-party dependencies (report upstream); our hosted infrastructure (contact support@clawde.io).

## Disclosure Policy

We follow coordinated disclosure. Please give us 90 days to patch before public disclosure.

## Security Advisory Template

When reporting a security issue, please include:

1. **Summary** — one-sentence description of the vulnerability
2. **Severity** — Critical / High / Medium / Low
3. **Affected component** — daemon, Flutter app, Dart package
4. **Affected versions** — e.g., "all versions <= 0.2.0"
5. **Steps to reproduce** — minimal reproduction steps
6. **Impact** — what an attacker could achieve
7. **Suggested fix** (optional) — if you have one

Report to: **security@clawde.io** or via GitHub Private Security Advisory.
