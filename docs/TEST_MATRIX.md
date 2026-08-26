# v0.1.0 test matrix

## Input-source combinations

| Server before leave | Remote Mac | While remote | On return |
| --- | --- | --- | --- |
| Pinyin | Pinyin | Server ABC; remote unchanged | Server Pinyin |
| Pinyin | ABC | Server ABC; remote unchanged | Server Pinyin |
| ABC | Pinyin | No saved state; remote unchanged | Server ABC |
| ABC | ABC | No saved state | Server ABC |

## Transition and recovery cases

- Normal leave and enter
- Duplicate leave
- Duplicate enter
- Fifty rapid leave/enter cycles
- Local-to-remote-to-remote-to-local
- Restart while remote with a saved source
- Graceful guard shutdown while remote
- Forced guard termination and launchd restart
- Synergy server stop without a `stopped server` log line
- Language sync enabled after guard startup
- Failed ABC selection
- Failed restoration followed by retry
- Unknown current input source with and without saved state
- Client-side transition log events
- Log replacement and truncation
- Missing log at startup
- Sleep/wake followed by explicit cursor boundary crossing

## Installation cases

- Fresh install
- Idempotent reinstall
- Upgrade with an existing saved state
- Activation failure rollback
- Uninstall while local
- Uninstall while remote
- Paths containing spaces
- Language sync enabled preflight failure
- Synergy not running preflight failure
