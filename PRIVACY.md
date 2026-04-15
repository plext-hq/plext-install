# Plext Privacy Policy

Last updated: 2026-04-14

Plext is designed to collect as little information as possible while still giving us enough signal to improve the product. This document covers every place data leaves your machine.

## Telemetry is opt-in

On first run, Plext asks:

```
Plext can send anonymous usage data to help us improve the tool.
No code, transcripts, or personal information is ever collected.
See https://plext.com/privacy for details.

Send anonymous usage data? [y/N]:
```

The default is **no**. Your choice is stored at `~/.plext/telemetry.json` (or the equivalent location on Windows) and you are never asked again unless you reset it.

You can change your choice at any time:

- `plext telemetry on` — enable
- `plext telemetry off` — disable
- `plext telemetry status` — show current setting
- `plext telemetry reset` — regenerate the anonymous installation ID
- `PLEXT_TELEMETRY=off` — per-invocation override (useful in CI)

## What we collect (only if you opt in)

Every event includes:

- `installation_id` — an anonymous UUID generated locally on first run. Not linked to any identity.
- `plext_version` — the CLI version string.
- `os` / `arch` — e.g. `darwin/arm64`.
- `timestamp`.

Plus one of:

| Event | Properties |
|---|---|
| `command_invoked` | Subcommand name and flag *names* (never flag values). |
| `error_occurred` | Error *type* and exit code. |
| `install_completed` / `update_completed` / `uninstall` | Version transitions. |

## What we never collect

- Transcript content, prompts, or results
- File paths, project names, or directory structures
- Error message strings (they can contain user data)
- Environment variables
- Git commit messages, diffs, or branch names
- Notes, plexes, or any workspace content
- Your name, email, IP address, or any account identifier (we don't have accounts tied to telemetry)

## Where data goes

Anonymous events are sent to [PostHog](https://posthog.com) US cloud (`us.i.posthog.com`). The PostHog project API key embedded in the binary is **write-only**: it cannot read data back out.

## Transport

- HTTPS only.
- 3-second timeout. If the network fails, events are dropped — we never queue or retry.
- All telemetry runs in a background goroutine and cannot delay a plext command.

## Deletion

To delete prior telemetry:

1. Run `plext telemetry reset` to cut the link between your machine and any past events.
2. Email `privacy@plext.com` with the installation ID shown by `plext telemetry status` before you reset, and we will issue a PostHog deletion request for events tied to that ID.

## Network calls Plext makes regardless of telemetry

Plext is a CLI that talks to the Plext web API. Independent of telemetry, these requests go out during normal use:

- **Plext API** (`https://www.plext.com/api/...`) — authentication, workspaces, plexes, notes. Requires login.
- **Version check** (`https://dl.plext.com/latest/version.txt`) — lightweight `GET` on each invocation to see if an upgrade is available. No identifiers sent. Set `PLEXT_NO_UPDATE_CHECK=1` to disable.

These are product calls, not telemetry, and they are required for the CLI to do its job.

## Questions

Email `privacy@plext.com`.
