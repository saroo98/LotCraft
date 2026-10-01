# LotCraft 1.2.2 release evidence

The owner authorizes commits, push and publication of the numeric-copy fixes on 2026-10-01. The [release plan](RELEASE_PLAN_2026-10-01.md) tracks current status. The [copy audit](COPY_AUDIT_2026-10-01.md) records failing regressions, source fixes and native verification limits.

## Changes

- Ctrl+C copies whole, partial and reverse selections in numeric editors without committing or recalculating.
- C buttons preserve the formatted planning price instead of imposing trade normalization again.
- A zero chart-window owner fails before clearing clipboard contents.
- Failed button or shortcut copies clear old success feedback and log only a generic rate-limited reason.
- EA, setup, PE metadata and signed-release identities advance to 1.2.2. Persistence namespaces, trading semantics, layouts and updater timing stay unchanged.

## Local verification

| Check | Fresh observed result | Boundary |
|---|---|---|
| Python suite | 443 passed, two skipped in 77.70s; zero failures/errors | Two private-station clipboard fixtures cannot create isolation (Windows error 183). All 41 production-function copy cases pass |
| Go tests | Four packages passed uncached, normally and with race detection | Disposable directories and synthetic fixture keys only |
| Go vet | Exit 0 | Current 1.2.2 source |
| Signed release build | Exit 0; MetaEditor zero errors and zero warnings | Hidden compiler; no MT5 launch or production installation |
| PE metadata and signature | 1.2.2.0 metadata verified; Ed25519 signature and signed installer descriptor match | Existing pinned key; no key or credential changes |
| Windows security scan | Custom scan completed; zero matching detection records for the new setup; setup remains readable and executes in the fixture | Does not certify other machines or classify older detections as false positives |
| Embedded-payload smoke install | Exit 0; schema 2, version 1.2.2, exactly four owned files | Disposable terminal-like directory, no explicit payload override |
| Payload identity | Canonical, staged and disposable-installed EX5 match; both helpers match setup | Public verification JSON's installed role refers to this fixture, not a production terminal |
| Privacy and diff | 30 changed-source/public-asset candidates scanned with zero narrow private-pattern matches; whitespace check passed | Heuristic, not a full-history credential audit; private raw logs/JUnit excluded |
| Build placeholder | Exact tracked embedded placeholder restored | Compiled payload not committed into source |

The first smoke attempt correctly rejected a disposable fixture with only an empty MQL5 directory. Adding its normal config marker allowed installation; no installer validation was weakened. The installation guide now states the actual marker requirement.

## Release artifacts

| Artifact | Size (bytes) | SHA-256 |
|---|---:|---|
| `LotCraft-1.2.2-Setup.exe` | 6,934,528 | `ba73e7d2af59bcc6455d856ed30a74eef3d343e02dd18d1fbc9835af88bdd406` |
| `LotCraft-update.json` | 256 | `b8c00eb2a4fc39d730ad1d65fbfb21b246fd604e83e7a33fc02360e582728035` |
| `LotCraft-update.sig` | 89 | `37efccd8df09a9ecb8083c867bc0816c4d6e708bb99fb727a8b8b258820f2d96` |
| `LotCraft.ex5` (embedded, not uploaded separately) | 269,506 | `82cef028f783d061049642a4a84aa5ecadf620665611c2ded84fc5578dfb14a6` |

The intended public inventory contains the setup, versioned checksum, signed JSON, signature and path-redacted verification JSON. No raw logs, local installation manifests, private keys or terminal paths are public assets.

## Publication status

Local release gates pass. Commit, push, publication and public-download verification are the next steps. No production installation, MT5 runtime acceptance or universal notification claim is made.

## Delivery limits

An eligible installed updater can offer 1.2.2 at its next permitted check. Version 1.2.1 checks through hourly launch opportunities and a 24-hour attempt throttle. Older EAs can require reattachment or a normal restart. Offline machines, deferrals, verification failures, disabled DLL imports and Windows security blocks prevent a guaranteed notification deadline.

The first installer is not Authenticode-signed. Ed25519 signed metadata protects eligible subsequent updates with the existing pinned key. Native MT5 keyboard events, MQL DLL marshalling and real Windows UTF-16 clipboard round trips remain unverified; the safe real-clipboard fixtures skip when private-station isolation is unavailable.
