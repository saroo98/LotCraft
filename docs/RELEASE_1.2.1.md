# LotCraft 1.2.1 release evidence

This release includes the September audit repairs and recurring background update opportunities. The owner approved commits, push and signed publication on 2026-09-30. The [release plan](RELEASE_PLAN_2026-09-30.md) tracks live status. Earlier audit results remain historical, not fresh release acceptance.

## Changes

- Per-symbol plans restore the last chosen SL when returning on the same chart.
- Mode changes preserve SL/TP; invalid saved geometry stays visible but cannot trade.
- Nearby level handles separate horizontally without changing their true price.
- Market schedule handling distinguishes invalid or ambiguous data from known closure.
- Exposure completeness, editor bounds, rendering recovery and Full-mode action selection are hardened.
- Installer ownership/path checks, rollback error reporting, worker cleanup and private-key creation safeguards are retained from the reviewed audit fixes.
- The detached updater gets an initial launch opportunity after ten seconds, then hourly opportunities while the EA stays attached. It retains the per-installation 24-hour attempt throttle, signed stable-release checks and user approval.

## Local verification

| Check | Observed result | Boundary |
|---|---|---|
| Full Python suite | 402 passed in 51.13s; JUnit: 0 failures/errors/skips | `py -3.11 -m pytest -q --junitxml=build/release-1.2.1-pytest.xml --tb=short`; ignored local JUnit, not a public asset |
| Go tests | All four packages passed uncached | Disposable test installations/keys only |
| Go race tests | All four packages passed uncached | No antivirus exclusions or protection changes |
| Go static analysis | `go vet ./...` exit 0 | Current Go source |
| Signed release build | Release script exit 0; MetaEditor 0 errors / 0 warnings, 3015ms | Hidden compiler, no MT5 launch or production installation |
| Windows metadata/checksum | PE version verification exit 0 | Windows x64 GUI installer identifies 1.2.1 |
| Signature and descriptor | Ed25519 verification passed; installer size/SHA-256 match signed JSON | Existing pinned key, no production key generation/rotation |
| Packaged payload smoke install | Exit 0, schema 2, version 1.2.1, four owned files | Disposable terminal-like directory; no explicit payload override or MT5 launch |
| Payload identity | Canonical, staged and disposable-installed EX5 match; updater/uninstaller match setup | Verifies the actual embedded release payload, not production activation |
| Privacy scan | 79 current source candidates and all five release assets: no matching private-path/common credential patterns | Narrow heuristic, not a full-history or security certification |
| Existing private key permissions | Protected DACL, zero other-user Allow rules | Permissions checked without printing key contents or changing them |
| Embedded build placeholder | Exact tracked bytes restored after release build | No compiled payload committed into the source placeholder |
| Whitespace | `git diff --check` exit 0 after README cleanup | Intentional Markdown hard-break spaces replaced with blank paragraphs |

The [stable 1.2.1 release](https://github.com/saroo98/LotCraft/releases/tag/v1.2.1) is published and public download verification is complete. Native MT5 acceptance remains outside these gates.

Initial scheduler feature checks failed because the new function was absent. After implementation, the three production-function schedule cases and four adjacent updater contracts passed (7 cases, 3.50s). Schedule tests launch neither MT5 nor a network-facing updater.

## Release artifacts

| Artifact | Size (bytes) | SHA-256 |
|---|---:|---|
| `LotCraft-1.2.1-Setup.exe` | 6,934,016 | `b466937d14ae4e62f84eb192a4bc6f8b78d5b923aa686c7e983da07413a5da60` |
| `LotCraft-update.json` | 256 | `2b2a88b04eb17eed8795423c41dfc16e168230659d1ff0107c9ff94173fe6cd9` |
| `LotCraft-update.sig` | 89 | `8c7d1d45c19d1f7c9032e95a927cd16c9ba008e8b39a842f23257e8ed99a2b42` |
| `LotCraft.ex5` (embedded, not uploaded separately) | 269,252 | `98beadc1990440fff69416eb6f17e0390fd19f2562ae15ac300e7cff18370f24` |

The public asset inventory is the setup, `LotCraft-1.2.1-SHA256.txt`, signed JSON, detached signature and `RELEASE-VERIFICATION.json`. Compiler logs, raw test logs, installation manifests, private keys and local absolute paths are not release assets. The separate approved 1.2.0 report-only repair is recorded below.

## Public publication verification

- Thirteen focused source/test/documentation commits were pushed without force to both the default branch and `feat/sl-exposure-ui-hardening`. Annotated tag `v1.2.1` resolves to `4054fd16e5ea578b9072e31116944bf7cd185601`, the verified code tree. Later evidence-only commits do not move this tag.
- The release was uploaded as a draft. All five assets had matching local size and GitHub SHA-256 digest before publication. It was then published as latest at `2026-09-30T08:22:04Z`.
- The public latest-release API reports `v1.2.1`, not a draft or prerelease, with exactly the five intended assets. All five fresh public downloads match the verified local byte sizes and SHA-256 hashes.
- The production Go `Checker` was run anonymously against the real latest-release endpoint with installed version `1.2.0`. It accepted `1.2.1`, verified the Ed25519 signature with the pinned key, and downloaded and verified the 6,934,016-byte installer with the SHA-256 above. With current version `1.2.1`, it returned no update candidate. This invoked no installer, popup, EA or MT5 terminal.
- Both production installations were checked read-only after publication. All eight owned-file hashes match the earlier baseline. The separate dirty checkout retains its original HEAD and modified/untracked inventory. Neither checkout inspection nor release verification changed production files.
- Final documentation validation passed: 79 static-contract tests in 0.23s, eight valid README document links, and `git diff --check` exit 0. A further narrow private-pattern scan covered 57 changed source files and six downloaded public assets (the five new assets plus the redacted old report), with no matches. This is not a full-history credential audit.

The standalone checker exercise bypasses local scheduling/state and installation verification. It proves public signed-release eligibility and download integrity, not that any user's installed updater has launched, prompted, installed or activated the EA.

## Approved old report privacy repair

Only [v1.2.0's verification report](https://github.com/saroo98/LotCraft/releases/download/v1.2.0/RELEASE-VERIFICATION.json) was replaced after explicit owner approval. Seven absolute `path` fields became their artifact basenames. A recursive comparison confirmed that every non-path value, including timestamps, sizes, hashes and compile results, stayed unchanged. This does not turn historical evidence into fresh acceptance.

The original report is retained only in an ignored private backup. The replacement public download matches the redacted bytes: 2,001 bytes, SHA-256 `a95b387286d369995eecc8b05fdc26ff4d0a368e32993bf64f12c3f2ba6c22a4`.

The other four old asset IDs, sizes, SHA-256 digests and upload states are unchanged. The release ID, tag, target, publication time, title, draft/prerelease state and release-notes hash are unchanged. Latest remains `v1.2.1`. No old installer, checksum, signed JSON or signature was replaced; prior cached report copies are outside this repair.

## Update delivery limits

The published release must be newer than the installed version and use the existing pinned signing key. Version 1.2.0 still requires a normal reattachment or restart to launch its next eligible check. New 1.2.1 instances provide recurring opportunities; a push cannot change an older binary's behavior. Offline machines, throttling, deferral, failed installation verification, network failures or disabled DLL imports prevent a universal notification deadline.

GitHub release announcements go to users who subscribe and enable delivery. Publication does not force a notification to everyone who downloaded an installer.

## Unverified runtime

No live MT5 UI, trade, production install, forced restart or desktop control is used. Actual popup presentation, user approval, loaded-EA replacement/activation, native rendering and broker acceptance remain unverified. Installer rollback handles detected failures, not power-loss-atomic replacement. The existing terminal-global plan lifetime and account/server/chart namespace remain unchanged.
