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
  (`/authorize`, `/token`, `/introspect`, `/revoke`) or external IdP verification.
- `X-Forwarded-*` spoofing past the trusted-proxies allowlist.
- Path traversal, symlink escape, or denied-path bypass outside an approved workspace.
- Project-memory isolation failures, including unauthorized `.mcpgate` mutation,
  revision-precondition bypass, or disclosure of memory bodies / detected credential-like values.
- Session admission or lifecycle bypass that exceeds configured capacity, reuses
  closing session identity, escapes draining, or observes a mixed policy generation.
- Command injection or command-policy bypass through agent tools, bridge, or boost.
- Configured-upstream policy bypass that lets client/workspace input introduce or widen trusted bridge/boost process topology or environment inheritance.
- Cross-session access caused by misuse of Streamable logical-session correlation or MCP session identifiers.
- Confirmation authorization replay, wrong-scope reuse, mutation, or stale-policy acceptance.
- Privilege escalation through the authenticated admin/dashboard surfaces.
- Information disclosure of master keys, OAuth secrets, confirmation records,
  private workspace paths on public endpoints, raw tool arguments/results, or sensitive audit data.
- Denial-of-service through default-config resource exhaustion, unbounded queues,
  subprocess trees, session/goroutine growth, or protocol buffering.
- Dependency or Go standard-library vulnerabilities with a concrete reachable path in MCPGate.

## Out of scope

- Issues requiring the attacker to already have trusted local-user access to the
  machine running MCPGate, except where a documented cross-user boundary is intended.
- The deliberate opt-in `--no-auth` mode exposing endpoints when the operator has
  explicitly enabled the required unsafe public override.
- Theoretical issues without a concrete proof-of-concept or reachable security impact.
- Findings in third-party MCP servers proxied through bridge/boost that do not
  result from MCPGate's own validation, isolation, or transport behavior.

---

## Runtime security properties

- **Atomic policy publication:** global runtime policy and retained active workspace
  overlays are validated before publication. An invalid workspace edit keeps its
  last-known-good overlay; a global replacement that would invalidate an active
  workspace is rejected as a whole. Reloadable sessions finishing setup during a
  concurrent publication catch up before becoming registry-visible.
- **Bounded admission and lifecycle:** stateful session capacity is reserved before
  setup, expensive setup/tool work passes through bounded fair admission queues,
  and cancellation/draining/resource-pressure failures return stable recovery
  guidance without exposing principal or workspace identifiers in public telemetry.
- **Command and subprocess containment:** command execution is allow-list based;
  argument policy, immutable timeout snapshots, bounded output, process-tree cleanup,
  and optional execution-memory ceilings apply to agent tools and bridge/boost work.
  All git tool arguments are validated against option injection and invalid ref formats,
  git remote URLs enforce safe transport protocols, and git remote destinations can be
  strictly confined via `tools.allowGitRemoteHosts`. Dedicated tools support subcommand
  deny policies via `tools.denySubcommands`, and read-only directory paths can be
  enforced via `permissions.additionalReadOnlyPaths`.
- **Trusted bridge/boost topology:** upstream processes are defined by global
  configuration. Workspace policy may tighten inherited definitions but cannot add
  new executables or widen inherited environment/startup/timeout policy.
- **Session correlation isolation:** logical-session hints are correlation only,
  never authorization, and are accepted only inside the authenticated session scope.
  Raw correlation and MCP session identifiers are excluded from ordinary lifecycle telemetry.
- **Standard confirmation flows:** confirmation is capability-driven and uses MCP
  form elicitation when advertised. Pending authorizations are random, expiring,
  single-use, and bound to the exact invocation, authenticated scope, and policy
  identity; replay, mutation, wrong-scope, and stale-policy retries fail closed.
- **Memory isolation:** dedicated project-memory operations use a confined,
  identity-pinned root with optimistic revisions and sensitive-content scanning.
  Generic filesystem tools do not gain a write path into `.mcpgate`, and audit
  records omit memory bodies and detected credential-like values.
- **Authentication & CSRF protection:** session-backed mutating routes and OAuth
  authorization requests require double-submit CSRF tokens; the master-key entry
  path on `/authorize` is self-authenticating and preserves round-trip parameters on retry.
- **Sanitized diagnostics:** public health and metrics expose aggregate or
  low-cardinality state. Authenticated operator surfaces may expose workspace
  validation details needed for remediation, but credentials, raw tool arguments,
  results, confirmation secrets, and sensitive subprocess payloads are excluded.

---

## Supply-chain integrity

Every published archive contains the platform binary and the proprietary
license.

Each archive is signed offline by the maintainer with an ed25519 key whose
public half is reproduced in `install.sh` and baked into every release binary.
Both the installer and `mcpgate update` verify `checksums.txt` and the archive
signature; missing or invalid signatures are refused without modifying the
running binary.

The signing key is kept offline. Consequently:

- Compromise of this repository alone cannot produce a binary accepted by the
  installer or updater.
- Tampering with an archive, its checksum entry, or both is detected before
  installation because the archive must also match the offline signature.
- A signing-key rotation requires users to reinstall through the documented
  installer so they receive a binary containing the new public key.

Manual verification commands are documented in the [Releases README](README.md#verifying-a-release-manually).

---

*This policy applies to the binaries and installers published in this
repository.*
