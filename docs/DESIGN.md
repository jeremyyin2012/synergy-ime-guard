# Design

## Problem

When a Mac is the Synergy 3 server and Simplified Chinese Pinyin is the active
input source, punctuation keys such as comma and period may not reach a remote
screen. Switching the server to the ABC keyboard layout avoids the bug, but
requiring users to manage the server input source on every screen transition is
not practical.

The upstream behavior is tracked by Deskflow issues
[#9465](https://github.com/deskflow/deskflow/issues/9465),
[#9791](https://github.com/deskflow/deskflow/issues/9791), and
[#9332](https://github.com/deskflow/deskflow/issues/9332).

## Current scope

Synergy IME Guard is a macOS-only, per-user LaunchAgent. It:

1. Observes Synergy's local transition log.
2. Acts only while this Mac is the active Synergy server.
3. Saves the current macOS input source before the cursor leaves the Mac.
4. Selects the ABC keyboard layout while the cursor is remote.
5. Restores the saved input source when the cursor returns or the server stops.

The tool does not modify, embed, or redistribute Synergy. It does not send
network traffic and does not collect telemetry.

## Architecture

```text
Synergy log ──> transition parser ──> guard state machine
                                           │
Synergy process list ──> server-role gate ─┤
                                           │
macOS HIToolbox preferences ──> saved source / ABC selection
                                           │
durable state file <────────────────────────┘
```

The release runtime is a native Swift executable built as a universal macOS
binary. It has no third-party runtime or package dependency.

Runtime components:

- `ProcessDiscovery` parses the local `synergy-core` command line and discovers
  the role, screen name, and language-sync flag.
- `SystemSelection` reads the active user-session input source.
- `MacOSInputSource` uses the public Carbon Text Input Source APIs to select an
  input source.
- `Guard` owns transition processing, role gating, recovery, and log rotation.
- `StateStore` persists a restore obligation with an atomic fsync-and-rename.
- `LaunchAgent` renders a user-specific launchd plist without storing machine
  identifiers in the repository.

## State invariant

The state file is a durable restore obligation. Once a non-ABC source has been
saved, duplicate leave events, process restarts, log rotation, and failed input
source changes must not overwrite or clear it. Only a successful restoration
may clear the state.

This invariant prevents the most dangerous race: a restarted guard sees ABC
while the cursor is remote and incorrectly forgets which input source to
restore.

## Role model

Install the guard on every Mac that may become the Synergy server. A guard on a
client remains passive. Before processing a leave event, it proves that a local
`synergy-core server` process is running with the configured screen name.

For more than two screens, remote-to-remote transitions preserve the original
saved source. Restoration happens only when the cursor returns to the local
screen.

## Failure handling

| Failure | Behavior |
| --- | --- |
| Duplicate leave | Preserve the first saved source. |
| ABC selection fails | Keep state so return remains recoverable. |
| Restore fails | Keep state and retry on the next recovery event. |
| Guard receives `TERM` | Restore in the main loop before exit. |
| Guard is killed | launchd restarts it; startup reconciliation preserves state. |
| Synergy server disappears | Restore within the periodic health check. |
| Language sync is enabled later | Restore any saved source and remain passive. |
| Log is replaced or truncated | Reopen it and reconcile from the newest transition. |
| Input source cannot be determined | Do not guess or destroy state. |
| Process snapshot fails | Preserve state, write a diagnostic entry, and retry reconciliation. |

The periodic recovery check runs only while a restore obligation exists. It
uses one process snapshot every five seconds; normal cursor transitions remain
log-driven and keep their existing low latency. All subprocess pipe handles are
closed deterministically after each command.

## Compatibility boundary

The v0.1.x line is tested with:

- macOS 26.5.1 and 26.5.2
- Synergy 3.6.3
- Simplified Chinese Pinyin (`com.apple.inputmethod.SCIM.ITABC`)
- ABC (`com.apple.keylayout.ABC`)
- Two Apple Silicon Macs in active-server and passive-client roles

Deskflow and other Synergy-derived products are not claimed as supported until
their process and log contracts receive separate integration tests.

## Installation contract

The installer:

1. Requires an Aqua user session and a running Synergy core.
2. Discovers the local screen name from the process rather than accepting a
   repository-baked identifier.
3. Refuses to install while Synergy language sync is enabled.
4. Stages and validates all files before stopping an existing public agent.
5. Installs a checksum-verified universal Swift binary with no interpreter.
6. Backs up an existing installation and restores it if activation fails.
7. Never modifies Synergy certificates, encryption settings, or account data.

Uninstall first restores any saved source, unloads the LaunchAgent, and then
removes only paths owned by this project.

## Release gates

Each v0.1.x release requires:

- All XCTest unit and state-machine tests passing on macOS.
- Reproducible arm64 and x86_64 builds combined into one universal binary.
- Fresh install, upgrade, uninstall, rollback, and reinstall tests.
- Active-client and active-server tests on both reference Macs.
- No user names, IP addresses, certificates, fingerprints, Synergy databases,
  or runtime logs in Git history.
- English and Simplified Chinese operating documentation.
- A public changelog, security policy, license, and reproducible release tag.
