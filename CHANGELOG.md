# Changelog

All notable changes to this project will be documented in this file.

## [0.1.1] - 2026-09-21

### Fixed

- Close every subprocess pipe descriptor after command execution, preventing a
  long-running server guard from exhausting its file-descriptor limit and
  silently losing Synergy role detection.
- Read the Synergy process list once per role or health decision instead of
  launching separate snapshots for the server and language-sync checks.
- Match `synergy-core` only when it is the process executable, avoiding false
  role detection when an unrelated command merely mentions its full path.
- Report process-snapshot failures and explicit role/language-sync skips in the
  diagnostic logs instead of treating them as unexplained no-ops. Snapshot
  failures now preserve the current restore obligation and retry reconciliation
  instead of being mistaken for a stopped Synergy server.

### Changed

- Run pending-restore health checks every five seconds instead of every half
  second. Cursor transitions are still processed at the existing low latency;
  this interval only controls recovery from a stopped server or a language-sync
  setting change.
- Add regression coverage for repeated subprocess execution, standard-input
  pipe cleanup, process-discovery failures and retries, executable matching,
  and single-snapshot role gates.

## [0.1.0] - 2026-08-26

### Added

- Role-aware macOS input-source guard for Synergy 3.
- Durable restore state with atomic writes.
- Recovery for duplicate events, process restarts, server loss, and log rotation.
- Per-user LaunchAgent installer, diagnostics, status, and uninstall workflow.
- English and Simplified Chinese documentation.
- Automated state-machine and compatibility tests.
