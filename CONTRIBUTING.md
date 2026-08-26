# Contributing

Bug reports should include the macOS version, Synergy version, server/client
role, input-source identifiers, and redacted guard diagnostics. Never attach a
Synergy database, certificate, fingerprint, or unredacted log.

Before opening a pull request:

```sh
make check
```

Changes to the transition state machine must include a regression test and must
preserve the durable restore-state invariant described in `docs/DESIGN.md`.
