# Synergy IME Guard

Synergy IME Guard is a small native macOS helper for a Synergy 3 input bug:
when a Mac is the Synergy server and Simplified Chinese Pinyin is active,
punctuation such as comma and period may not reach the remote screen.

The guard temporarily selects the macOS ABC keyboard layout while the pointer
is on a remote screen and restores the user's original input source when the
pointer returns. It runs only on macOS, but the remote Synergy client may be
Windows, Linux, or macOS.

[简体中文说明](README.zh-CN.md)

## When this project applies

| Keyboard / Synergy server | Remote client | Guard needed? |
| --- | --- | --- |
| macOS with Chinese Pinyin | Windows, Linux, or macOS | Yes, on the Mac server |
| macOS using ABC only | Any supported client | Usually no |
| Windows or Linux | Any supported client | No; this macOS IME bug is not involved |

Install the guard on every Mac that may become the Synergy server. An installed
guard stays passive whenever that Mac is a client.

[Synergy itself supports Windows, macOS, and Linux](https://support.symless.com/hc/en-us/articles/33562793892497-Operating-system-and-hardware-requirements).
This project does not modify, embed, or redistribute Synergy.

This is an independent community workaround and is not affiliated with or
endorsed by Symless. Synergy is a trademark of its respective owner.

## Requirements

- macOS 13 or later on the Synergy server
- Synergy 3 with a local `synergy-core` process and transition log
- The built-in ABC input source enabled
- Synergy language synchronization disabled

v0.1.0 has been physically tested with Synergy 3.6.3, macOS 26.5.1 and 26.5.2,
Apple Silicon, Simplified Chinese Pinyin, and an active Mac server plus a passive
Mac client. Server/client process discovery and role gating are covered by
automated tests. Windows and Linux are supported by Synergy and are within the
guard's remote-client boundary, but were not part of the v0.1.0 physical test lab.

Deskflow is not yet claimed as supported; its process and log contracts need a
separate integration test.

## Install a release

Download both release files, verify the checksum, and install as the logged-in
macOS user. Do not use `sudo`.

```bash
curl -fLO https://github.com/jeremyyin2012/synergy-ime-guard/releases/download/v0.1.0/synergy-ime-guard-v0.1.0-macos-universal.tar.gz
curl -fLO https://github.com/jeremyyin2012/synergy-ime-guard/releases/download/v0.1.0/synergy-ime-guard-v0.1.0-macos-universal.tar.gz.sha256
shasum -a 256 -c synergy-ime-guard-v0.1.0-macos-universal.tar.gz.sha256
tar -xzf synergy-ime-guard-v0.1.0-macos-universal.tar.gz
cd synergy-ime-guard-v0.1.0-macos-universal
./install.sh
```

The installer discovers the current Synergy screen name. It refuses to proceed
if Synergy is not running, language synchronization is enabled, ABC is missing,
or the binary is incompatible with the current Mac. Official release archives
are universal; existing public installations are restored if activation fails.

The release is ad-hoc signed but not Apple-notarized. The checksum is the
release-integrity source of truth. Building from source is also supported.

## Status and diagnostics

```bash
"$HOME/Library/Application Support/SynergyIMEGuard/scripts/status.sh"
```

The diagnostic JSON reports the local Synergy role and screen name, language
sync state, current and saved input sources, ABC availability, and the last
known pointer location. It contains no keystrokes or typed text.

Runtime logs are stored in `~/Library/Logs/SynergyIMEGuard/`. A durable restore
state may temporarily exist under
`~/Library/Application Support/SynergyIMEGuard/state/` while the pointer is
remote. It is cleared only after a successful input-source restoration.

## Uninstall

```bash
"$HOME/Library/Application Support/SynergyIMEGuard/scripts/uninstall.sh"
```

The uninstaller restores a saved input source before removing the agent. If
restoration fails, it stops and preserves the executable and state for retry.
Pass `--keep-logs` to retain diagnostic logs.

## Build and test

Xcode with the Swift 5.9 package toolchain or later is required.

```bash
swift test
./scripts/build-release.sh
```

The release script builds arm64 and x86_64 executables, combines them into one
universal binary, applies an ad-hoc code signature, creates the archive, and
writes its SHA-256 checksum.

## How it stays safe

- Acts only when this Mac is the named Synergy server.
- Never records key events, clipboard contents, or typed text.
- Makes no network requests and has no telemetry.
- Does not change Synergy certificates, encryption, account data, or topology.
- Persists the original input source before selecting ABC.
- Never overwrites a pending restore obligation on duplicate events.
- Restores on return, server loss, graceful shutdown, uninstall, and upgrade.

See [the design](docs/DESIGN.md), [test matrix](docs/TEST_MATRIX.md), and
[security policy](SECURITY.md) for details.

## Upstream context

The behavior is tracked in Deskflow issues
[#9465](https://github.com/deskflow/deskflow/issues/9465),
[#9791](https://github.com/deskflow/deskflow/issues/9791), and
[#9332](https://github.com/deskflow/deskflow/issues/9332).

## License

MIT
