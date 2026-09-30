# LotCraft verification evidence, 2026-09-30

This is the completed pre-release audit snapshot. Later owner-authorized 1.2.1 build/publication work is recorded separately in [the release report](RELEASE_1.2.1.md); it does not retroactively change the audit results below.

This report applies to the uncommitted current source at `a97a76326e8ad0ccc58ce4aa0af3727aa807fe1f` in `feat/sl-exposure-ui-hardening`, including retained earlier audit changes. It does not relabel September 9/10 results as current. No production installation, desktop control, MT5 launch, live trade, real-key change/read, commit, push or publication occurred.

## Root-cause and narrow checks

| Check | Actual result | Scope |
|---|---|---|
| Existing risk/controller/UI baseline | 84 passed in 20.27s | Current inputs before September 30 repairs |
| Initial actual plan/marker regressions | Four expected assertion failures; legacy case passed | Overwritten symbol plan, translated SL, discarded invalid saved plan, inaccessible nearby markers |
| Actual controller transition with baseline EA body | Expected failure restoring EURUSD SL | Current storage helpers plus the old controller still reset the plan; current controller passes |
| Broker session cases | 17 passed | Date-independent intervals, overnight/weekly/full-day cases, ambiguous/negative records; three new cases failed baseline |
| Market-only fresh Pending plan | Fails baseline; passes repair | Actual builder produces planning geometry; actual validator rejects Pending; Instant recovery preserves SL |
| Label collision regression | Four scale cases failed before lane repair | Actual painter overlapped the separated handles at scale 0.82/1/1.5/2 |
| Final focused plan/exposure/capture/static run | 113 passed in 23.06s | Current controller, storage, marker geometry/hits, label painter and static contracts |
| Minimum-volume guidance regression | Fails before fix; passes in 0.64s | Actual risk function retains minimum-volume semantics and names Actual SL loss |
| Updated reference models | 132 passed in 0.11s | Calculation, trade safety, exposure and editor; four stale-contract failures and missing reference capability check repaired |

Native-function tests compile actual extracted MQL bodies as C++17. Terminal storage, quote, canvas, clock and allocation APIs are stubs. Reference models remain additional specification checks, not production implementation or broker evidence. A fixture viewport error was corrected before recording the controller baseline assertion. No failed fixture build is claimed as a reproduced product defect.

## Final gates

| Command/check | Actual result | Boundary |
|---|---|---|
| Hidden MetaEditor copied-source compile | `0 errors, 0 warnings`, 3245ms | MetaEditor 5.0.0.6182, 12 copied EA files, X64 Regular |
| Compiler source/current comparison | 12 files, 0 SHA-256 mismatches | No canonical/packaged/installed EA replacement |
| `go test -count=1 ./...` | Four packages passed, uncached | Releasesign 0.310s, setup 7.304s, policy 0.233s, update 0.678s |
| `go test -race -count=1 ./...` | Four packages passed, uncached | Releasesign 1.409s, setup 14.086s, policy 1.128s, update 1.767s |
| `go vet ./...` | Exit 0 | Current Go source |
| First full Python invocation | Process exited during PE checksum with a Windows access violation | No completed-suite result; no valid JUnit acceptance claim |
| Isolated `tests/test_installer_binary.py` after crash | 5 passed in 3.41s | Fresh synthetic current-source installer, no real EX5 or signing key |
| Full serial Python rerun | 399 passed in 52.26s, exit 0 | `py -3.11 -m pytest -q --junitxml=build/audit-20260930/pytest-results.xml --tb=short` |
| Final JUnit count check | 399 tests, 0 failures, 0 errors, 0 skipped | Recorded suite duration 52.186s; [local JUnit evidence](../build/audit-20260930/pytest-results.xml) |
| Installed-file comparison | 2 installations, 8 owned files, 0 SHA-256 mismatches | Read-only comparison with this turn's baseline; no production write |
| Final copied-source comparison | 12 files, 0 SHA-256 mismatches | All compiled inputs still match the current EA source |
| Current source credential-pattern scan | 76 tracked/nonignored candidate files, 0 matching files, 0 credential-named files | PEM private-key headers, common GitHub/API key patterns and credential filenames only; not a history scan or security certification |
| `git diff --check` | Final check exit 0 | 31 existing LF-to-CRLF conversion notices, no whitespace errors |
| `gofmt -l cmd internal` | Exit 0; five pre-existing unformatted files | `main_other.go`, `windowspath.go`, `windowspath_test.go`, `protocol.go`, `protocol_test.go`; these files are untouched, so no unrelated formatting churn was introduced |

The checksum function is pure Python. The application event records `python.exe`, exception `c0000005`, faulting module `unknown`, offset zero. The exact crash cause is not established. Passing isolated tests do not prove the crash was fixed. No checksum code was changed or assertion weakened, and no security controls were bypassed. The serial full-suite rerun is a separate acceptance check.

The compiler process reported exit code 1; compilation acceptance is based on the full diagnostic summary, the nonempty EX5 and exact input comparison, not that exit code. The audit EX5 is 269,184 bytes, SHA-256 `e3bf02bd1f2144e7ff170f33c27255bfd6d610b6134c0471f1616cc6d889e8c7`. It is an unpublished [audit build](../build/audit-20260930/compile/LotCraft.ex5). The [compiler log](../build/audit-20260930/compile/compile.log) is ignored local evidence and can contain local include paths; do not publish it as a release asset without sanitization.

## Production and public-state checks

Two local manifests currently report schema 2/version 1.2.0. Read-only baseline hashes:

| Owned file | SHA-256 |
|---|---|
| EX5, both copies | `78dd3b22f5a0d29bbae377efd24291c2c75f2caab644cc58449113e9ff3b4ddb` |
| Updater/uninstaller, both copies | `46a6c34f329b744f6547a94163c21e1339d7272cf5ab12d877e6d70a1c6a5756` |
| Local manifests | Digests recorded locally and omitted from public evidence because they identify private installation records |

The latest-release API still reports stable v1.2.0, published 2026-08-08, with five assets. No release installer was executed and no remote asset was changed. Earlier signature/download verification remains historical unless separately repeated.

Final installed-file and frozen-source hashes match their captured values. The separate main checkout retains HEAD `142441be9fb103ce2eafe1c6cff2f7a5c159349b` and its pre-existing modified risk file/untracked planning directory. The active worktree retains HEAD `a97a76326e8ad0ccc58ce4aa0af3727aa807fe1f`; all audit changes remain uncommitted. No commit or remote mutation occurred. Account/terminal identifiers and signing material are excluded from this report.

The incremental source/test/documentation changes were reviewed against the ignored pre-repair snapshot. Existing September audit changes remain in place. Build output, compiler log and JUnit evidence are ignored by Git. No generated binary was copied to canonical, packaged or installed paths.

## Unverified acceptance

Hyper-V inventory is permission-blocked; no isolated MT5 runtime was established. Actual raster/fonts, pointer/IME/Win32 behavior, chart/timeframe event ordering, restart/global-variable persistence, multi-instance lifecycle, resource/performance duration, broker conversion/contracts/session interpretation and execution remain unproven. The friend's exact rejection needs his error/retcode, broker symbol suffix, mode and installed version. No broker guard was relaxed to make a button clickable.

Terminal-global storage expires after four weeks without access and is account/server/chart-scoped, not indefinite archival storage. Actual update popup/download/install/reattachment activation and power-loss recovery are also unverified. Current setup rollback is detected-error per-file rollback, not crash-atomic commitment.

See the [audit and live implementation plan](AUDIT_2026-09-30.md) for findings, acceptance and ranked optional work.
