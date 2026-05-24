# Security Policy

## Reporting a vulnerability

**Please do not file a public GitHub issue for security-sensitive findings.**
Public disclosure before a fix is available puts every operator at risk.

Instead, report privately via one of the following:

- **GitHub Security Advisory** — use the green
  [*Report a vulnerability*](../../security/advisories/new) button in the
  **Security** tab of this repository. This is the preferred channel because
  it creates a private collaborative thread between you and the maintainer.
- **Direct contact** — email the maintainer via the address on the
  [maintainer's GitHub profile](https://github.com/FojleRabbiRabib).

In your report, please include:

- A clear description of the issue and its impact.
- A minimal reproduction (URL, command, payload, expected vs actual behaviour).
- The mcpgate version (`mcpgate version`) and OS/arch.
- Any logs or stack traces that don't contain credentials.

## Response SLA

| Severity              | Acknowledgement | Patch target |
|-----------------------|-----------------|--------------|
| Critical (CVSS ≥ 9.0) | 48 hours        | 7 days       |
| High (CVSS 7.0–8.9)   | 48 hours        | 14 days      |
| Medium / Low          | 48 hours        | 30 days      |

You will receive credit in the release notes for verified findings unless you
request anonymity.

## Supported versions

Only the latest published release receives security fixes. Older releases
are not patched; upgrade via `mcpgate update` to receive fixes.

| Version | Supported |
|---------|-----------|
| latest  | ✅        |
| older   | ❌        |

## In scope

- Bearer-token or master-API-key bypass.
- OAuth flow attacks against the built-in Authorization Server
  (`/authorize`, `/token`, `/introspect`, `/revoke`).
- External-IdP path attacks (JWT signature forgery, `alg=none` acceptance,
  JWKS spoofing, introspection-cache poisoning).
- `X-Forwarded-*` spoofing past the trusted-proxies allowlist.
- Path traversal escaping the workspace root.
- Command injection through any tool's argument plumbing.
- Privilege escalation via the admin endpoint.
- Information disclosure of the master API key or OAuth secrets in logs,
  error messages, or audit rows.
- Denial-of-service in a default configuration.
- Dependency vulnerabilities with a concrete exploit path in mcpgate.

## Out of scope

- Issues requiring the attacker to already have local user access on the
  machine running mcpgate (the threat model assumes the local machine is
  trusted).
- The deliberate opt-in `--no-auth` mode exposing endpoints — this is logged
  prominently when combined with a non-loopback bind.
- Theoretical issues without a proof-of-concept.
- Findings against third-party MCP servers proxied via bridge mode — file
  those upstream with the affected project.

---

## Supply-chain integrity

Every published archive is signed offline by the maintainer with an ed25519
key whose public half is reproduced in `install.sh` and baked into every
release binary at build time. Both the installer and `mcpgate update`
verify SHA256 **and** the ed25519 signature; releases missing or failing
their `.sig` are refused without modifying the running binary.

The private signing key never reaches CI or any system other than the
maintainer's offline storage. Consequently:

- A compromise of this releases repository (or the `RELEASES_PAT` token that
  GoReleaser uses to publish) cannot produce a binary that installs.
- Tampering with `<archive>` or `<archive>.sha256` is caught by signature
  verification at install time.
- A signing-key rotation orphans every running mcpgate from auto-update
  until users reinstall via `install.sh` (which re-fetches the embedded
  public key). The release notes for any such rotation will spell out the
  reinstall step prominently.

Manual verification commands are documented in the [Releases README](README.md#verifying-a-release-manually).

---

*This policy applies to the binaries published in this repository. The source
code lives in a private repository and is not part of the public attack surface
audit.*
