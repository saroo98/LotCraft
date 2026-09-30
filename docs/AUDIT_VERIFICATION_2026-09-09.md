# LotCraft audit verification evidence

Audit started: 2026-09-09. Final checks: 2026-09-10. Baseline source: `a97a76326e8ad0ccc58ce4aa0af3727aa807fe1f`.

## Boundaries

No live MT5 UI verification, desktop control, trading, production installation, real signing-key access, commit, push or publication was performed. Installer/ACL tests created disposable synthetic installations and ephemeral test keys only. Read-only GitHub release inspection and download did not modify remote state. Source/native-host tests do not prove MT5 rendering, broker execution or Win32 event integration.

## Commands and results

| Check | Result | Scope |
|---|---|---|
| Git status / worktree / history / tracked-file inventory | Clean release worktree at baseline | Separate main checkout is dirty and excluded |
| Applicable AGENTS.md search | None found under release repository or its ancestors | Supplied user working agreement applies |
| Production installation manifests, read-only | Two schema-2 installations report version 1.2.0 | Final comparison: all four owned hashes unchanged in both installations |
| Baseline `py -3.11 -m pytest -q` | 236 passed in12.20s | Includes static contracts, reference models and ignored prebuilt binary tests |
| Hyper-V `Get-VM -ErrorAction Stop` | Permission denied | Existing isolated VM cannot be established; no terminal launched |
| Public v1.2.0 release report, read-only | Absolute local paths confirmed | Remote artifact unchanged; local producer and failure output repaired |
| Existing updater temp-directory inventory, read-only |94 directories,646,599,680 bytes | No directories removed; worker cleanup defect confirmed |
| Baseline production owned-file SHA-256 checks | Two EX5 files match `78dd3b22f5a0d29bbae377efd24291c2c75f2caab644cc58449113e9ff3b4ddb`; updater/uninstaller copies match `46a6c34f329b744f6547a94163c21e1339d7272cf5ab12d877e6d70a1c6a5756` | Read-only, manifest hashes also recorded for final comparison |
| Controller/editor production-function regressions before fixes |4 expected assertion failures | Selection at32 chars, failed exposure refresh, invisible keyboard activation, return-to-original-symbol recovery |
| UI production-function regressions before fixes |6 expected assertion failures | Field bounds/cursor mapping, Compact containment, sidecar placement/page reachability, missing-SL warning |
| Installer/build/privacy regressions before fixes |3 expected Go failures and2 expected Python failures | Legacy collision, locked rollback restore, worker leak, public paths, missing alternate-build trust key |
| Phase 3 targeted production/reference/source suite | 228 passed in 3.28s | 54 production-function fixtures plus adjacent risk, exposure and trade checks; agent-run |
| Root independent risk/reference run before final two cases | 147 passed in 3.35s | 52 production-function and95 reference cases |
| `py -3.11 -m pytest tests/test_native_controller.py -q --tb=short` | 6 passed in 2.92s | Actual extracted controller/editor/snapshot functions compiled with deterministic platform stubs |
| Updated controller suite including render retry | 7 passed in 3.42s | Failed paint retains work and prevents details/labels from activating until recovery |
| Render-throttle mutation | Rejected by executable assertion | Removing the production retry gate fails the test; no repository mutation was applied |
| Initial audit-staged MetaEditor compile | 0 errors, 0 warnings, 4085ms | Hidden compiler, copied source under ignored audit build directory; superseded by final acceptance build below |
| Independent UI production-function run | 12 passed in 10.80s | Deterministic text metrics/geometry, not native visual acceptance |
| Tracked-file credential-pattern check | No matching credential/key filenames or common token/private-key patterns | Narrow heuristic, not a guarantee that all secrets or historical commits are absent |
| Phase 4 final risk/Full/static agent run |174 passed in12.50s |95 production-function cases and79 source contracts before independent-review repairs |
| Phase 4 final UI/static agent run |94 passed in14.26s |15 production-function UI cases plus79 contracts before independent-review repairs |
| Single new-order confirmation controller test | Pass; controller suite8 passed in3.77s | Actual PS_DoTrade sends refreshed revision once, cancel/invalid refresh send nothing, duplicate guard holds |
| Stale-confirmed-snapshot mutation | Rejected | Removing the copy of the refreshed snapshot fails the production controller assertion |
| Second staged compiler checkpoint |0 errors,0 warnings,4417ms | Before final independent-review capture/label repairs; not the final acceptance build |
| Production immutability checkpoint |All four owned hashes match baseline in both installations |Manifest and EX5/updater/uninstaller read-only checks; separate main checkout still has its original dirty-file/untracked-plan status |
| Independent-review F24/F32 repair suite |144 passed in22.19s |Actual capture/stepper/sidecar failure, UI/controller/Full behavior and static contracts; agent-run |
| Independent-review F30/F31 repair suite |172 passed in38.61s |Actual equity invalidation and bounded chart-label painter plus related suites; agent-run |
| Final audit-staged MetaEditor compile |0 errors,0 warnings,2925ms |After all EA acceptance repairs; log under ignored audit output, no installed/canonical copy replaced |
| Public latest-release API, read-only recheck |Stable v1.2.0; five assets |No remote write |
| Public manifest signature and actual installer descriptor |Ed25519 verify exit0; signed size/hash both match |Downloaded to ignored audit directory; executable was not run |

Final audit EX5 SHA-256: `2336aae4a1f7b3011a1934fb3536d410b8c4dc694f2d0537fe3113c35283a42c`.

Published v1.2.0 installer: 6,878,720 bytes, SHA-256 `46a6c34f329b744f6547a94163c21e1339d7272cf5ab12d877e6d70a1c6a5756`. Its signed metadata matches the actual downloaded bytes and the tracked public key. This verifies the existing release's integrity, not correctness of its historical code or delivery of these unpublished fixes.

## Consolidated gate

| Command/check | Actual result | Boundary |
|---|---|---|
| `py -3.11 -m pytest -q --junitxml=build/audit-20260910/pytest-results.xml --tb=short` |382 passed in 43.25s; 0 errors, 0 failures, 0 skips |Final frozen source, fresh synthetic PE and production-function fixtures; [JUnit evidence](../build/audit-20260910/pytest-results.xml), recorded suite time 43.218s |
| `go test -count=1 ./...` in installer |All four packages passed, uncached |Releasesign 0.338s, setup 6.634s, policy 0.180s, update 0.682s; disposable Windows fixtures |
| `go vet ./...` |Exit 0, including final rerun |Static Go analysis |
| Initial `go test -race -count=1 ./...` |Exit 1: setup test executable blocked by Windows antivirus as virus/PUA |Other three packages passed; worker spawn/copy tests blocked. No assistant protection changes or bypass |
| Final `go test -race -count=1 ./...` after user's allowance report |All four packages passed, exit 0 |Releasesign 1.427s, setup 14.024s, policy 1.156s, update 1.907s. Passing tests are not an antivirus verdict |
| `gofmt -l installer` |Changed Go files clean;5 untouched baseline files listed |Pre-existing formatting drift retained to avoid unrelated churn |
| `git diff --check` |Exit0 |No whitespace errors |
| Compile-input/current-source comparison |12 files,0 mismatches |[Final compiler log](../build/audit-20260910/compile-acceptance/compile.log) corresponds to current EA source |
| Final production immutability comparison |Two installations; all four owned hashes unchanged in each |Read-only EX5/updater/uninstaller/manifest hashes; no production mutation |
| Separate main checkout status / HEAD |Original modified risk module and untracked planning directory remain; HEAD unchanged |Unrelated work preserved at `142441be9fb103ce2eafe1c6cff2f7a5c159349b` |
| Final documentation/static rerun |79 passed in 0.28s |`py -3.11 -m pytest tests/test_static_contract.py -q --tb=short`; after final build-document wording corrections |

The user supplied a Windows Security screenshot naming `Trojan:Win32/Bearfoos.B!ml` for a temporary Go test executable and reported allowing it. The subsequent full race suite passed. The assistant did not change exclusions, disable protection, or run the downloaded release installer. Neither the allowance nor the passing rerun establishes whether the detection was correct or a false positive. Independent security review of the exact detected artifact remains unperformed.

Two Go helper entry tests intentionally skip in the normal parent test process and are invoked by their explicit isolated child-process tests. This is the helper harness protocol, not omitted acceptance coverage. There were no Python skips in the final JUnit result.

The native-function harness compiles extracted production function bodies as C++17. It does not reimplement their business logic. Platform types, market responses, canvas metrics and allocation failures are test stubs. This catches behavioral defects that source-string checks missed, but does not establish MQL ABI, UTF-16 behavior, event-queue behavior, visual appearance or broker correctness.

## Regression evidence map

The final Python/Go runs above include these files. Parameterized cases may share one test function. Earlier phase totals overlap and must not be added together.

| Findings | Executable coverage |
|---|---|
| F01-F04, F19, F21 | [Production risk/trade fixtures](../tests/test_native_risk_trade.py): pending fill versus trigger, weekly/overnight schedule, permission/connection gates, cached-quote planning, stops/freeze validation, incomplete inventory and count drift |
| F05, F09, F17, F18, F23 | [Production controller/editor fixtures](../tests/test_native_controller.py): failed refresh/copy, retry cadence, hidden focus, selected replacement, canceled transition; also one-stage refreshed trade confirmation |
| F06-F08, F20 | [Production UI fixtures](../tests/test_native_ui.py): incomplete scope states, row precision/pagination, clamping/DPI/padding, editor selection/cursor bounds, disabled reasons and semantic contrast |
| F24, F32 | [Capture/retry fixtures](../tests/test_native_render_capture.py) plus UI/controller tests: active drag/stepper cancellation, no later hidden save, invisible sidecar hit invalidation, independent bounded retries |
| F25, F26 | [Full-control and SL-batch fixtures](../tests/test_native_full_controls.py): clicked-half selection, active/gap/cross-half no-op, allocation/enumeration failure and transition during confirmation |
| F30, F31 | [Independent exposure review fixtures](../tests/test_native_exposure_review.py): equity-dependent displayed percentage and separated chart-label fields |
| F10, F11, F15 | [Verifier tests](../tests/test_release_verifier.py), [binary tests](../tests/test_installer_binary.py), [fresh PE fixture](../tests/conftest.py): path-safe success/failure, embedded pinned key, source-built nontrading payload |
| F12-F14, F22, F27-F29 | [Windows installer regression tests](../installer/cmd/setup/audit_regression_windows_test.go), existing updater tests: collisions, restore failure, worker cleanup, path linkage, reparse policy, lock contention, delayed cleanup and log bounds |
| F33 | [Signing collision tests](../installer/cmd/releasesign/main_test.go) and [pre-write native ACL test](../installer/cmd/releasesign/privatekey_windows_test.go): existing outputs unchanged and private DACL present before any secret bytes |
| F16 | Documentation/source cross-review and existing version/static contracts; documentation accuracy is not inferred solely from source-string tests |

Three mutation checks rejected deliberate removal of the render retry gate, refreshed trade-snapshot copy, and failed-panel interaction invalidation. These mutations ran in extracted fixture source, not in the retained repository files.

The final EA build used only copied audit source and a hidden MetaEditor process. The generated EX5 is [an ignored audit artifact](../build/audit-20260910/compile-acceptance/LotCraft.ex5), not the canonical packaged or installed binary. No full production release signing/build/install pipeline was executed. The synthetic installer build verifies current Go source and packaging behavior without real signing credentials.

## Runtime and visual limits

An already-configured isolated runtime was not established. Screenshots from prior tasks are historical inputs, not current execution evidence. The following acceptance remains unproven:

1. MT5 native raster/glyph appearance in both themes and Full/Compact/Mini at supported DPI and minimum chart sizes, including editor scrolling, exposure tile insets and long chart-label values.
2. Real pointer capture/release, S-over-E overlap, Instant E-to-Pending drag, symbol swaps, timeframe changes, disconnect/reconnect, allocation recovery and multi-chart behavior.
3. Clipboard/UTF-16/IME input, keyboard repeat, modal confirmation event ordering, and actual DLL behavior.
4. Terminal restart persistence, interrupted multi-key saves, long-running event/resource/performance behavior and chart-object cleanup.
5. Broker-specific contract conversion, tick/volume/margin constraints, market sessions, stop/freeze boundaries, partial fills/rejections and real inventory churn. No order was submitted.
6. Signed update download/install/popup/reattachment activation end to end, including a real approved junction. The existing published asset signature/size/hash check is read-only integrity evidence, not an upgrade test.
7. Power-loss/process-crash recovery across multi-file installer commits, beyond tested detected-error rollback. There is no crash-atomic transaction guarantee.

The main audit links each boundary to its external dependency or optional follow-up. No failed or prohibited runtime check is relabeled as passing.
