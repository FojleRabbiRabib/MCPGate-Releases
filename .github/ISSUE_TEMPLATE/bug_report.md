---
name: Bug report
about: Something isn't working as expected
title: "[bug] "
labels: bug
assignees: ''
---

## Summary

<!-- One sentence describing what's wrong. -->

## Environment

- **mcpgate version:** <!-- output of `mcpgate version` -->
- **OS / arch:** <!-- e.g. Ubuntu 24.04 / amd64, macOS 14 / arm64, Windows 11 / amd64 -->
- **Install method:** <!-- install.sh / manual / mcpgate update / built from source -->
- **MCP client:** <!-- ChatGPT connector, Claude Desktop, MCP Inspector, custom, … -->
- **Behind a reverse proxy?** <!-- yes (cloudflared/nginx/caddy/…) / no -->

## Reproduction steps

1.
2.
3.

## Expected behaviour

<!-- What you thought would happen. -->

## Actual behaviour

<!-- What actually happened. Include the HTTP status, response body, and the
     specific error message if there is one. -->

## Relevant logs

<!-- Logs from ~/.mcpgate/logs/mcpgate.log around the time of the issue.
     PLEASE REDACT bearer tokens, OAuth tokens, and the master API key
     before pasting. -->

```
<paste here>
```

## Workspace / config (optional)

<!-- If the bug depends on a specific workspace or config, list relevant
     fields here (or attach a sanitised `mcpgate config show` output). -->

---

> ⚠️ **Security issues should NOT be filed here.** See [SECURITY.md](../../blob/main/SECURITY.md) for the private disclosure process.
