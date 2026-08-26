# Security policy

## Supported versions

Security fixes are provided for the latest tagged release.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not
include Synergy certificates, fingerprints, account information, full runtime
logs, or other secrets in a public issue.

## Data and permissions

Synergy IME Guard is a native Swift executable that runs as the current macOS
user. It reads the local Synergy log, the local process list, and macOS
input-source preferences. It writes a small local state file and local
diagnostic logs. It does not use the network, collect telemetry, require root,
or request Accessibility permission.
