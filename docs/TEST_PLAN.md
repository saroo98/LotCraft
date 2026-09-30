# LotCraft 1.2.1 Test Plan

## 1. Test policy

- Use deterministic offline fixtures for domain arithmetic, editing semantics, trade-boundary behavior, source contracts, path policy, and installer binary structure.
- Use background MetaEditor for compilation. Chart interaction, lifecycle and server-policy acceptance require a separately authorized isolated Windows MT5/demo environment. The current audit does not launch a terminal or perform live UI verification.
- Do not place a live-account trade.
- Preserve compiler logs, Experts/Journal logs, screenshots or recordings for interaction cases, server retcodes, installer logs, manifests, and SHA-256 output.
- A static or mocked test is not evidence that MT5 rendered or executed the behavior correctly.

## 2. Automated test groups

| Group | Files | Required coverage |
|---|---|---|
| Calculation reference model | `tests/reference_model.py`, `tests/test_calculation.py` | Long/short, Instant, all pending subtypes, risk authorities, account modes, live basis changes, commission, symbol-class fixtures, currency conversion assumption boundary, min/max/limit, invalid data, stops, downward rounding |
| Numeric editor reference | `tests/test_editor.py` | Complete/incomplete parsing, decimal point/comma, signs, invalid text, NaN/infinity-like text, selection replacement, Backspace/Delete, finite large values |
| Trade boundary model | `tests/trade_reference.py`, `tests/test_trade_safety.py` | Permissions, single new-order confirmation/cancel, duplicate guard, server retcodes, netting guard, zero/one/multiple SL targets, eligibility/symbol filtering, partial failure, TP preservation |
| Source contract | `tests/test_static_contract.py` | Identity, exact control inventory, no native extra controls, line lock/handles, editor paths, persistence allowlist, confirmation stability, request separation, explicit structure copies, ownership cleanup, pointer-loss fallback |
| Installer policy | `installer/internal/policy/*`, `tests/test_installer_contract.py` | Windows path normalization, UNC paths, containment, deceptive prefixes, reparse resolution, staged commit/rollback, owned-file uninstall, predelete hash validation |
| Installer PE | `tests/test_installer_binary.py` | Windows x64 GUI PE, image version, version resource strings, zero timestamp, PE checksum |
| Release verifier | `tests/test_release_verifier.py` | UTF-16 compiler log parsing, zero-warning requirement, staged hash equality, installed hash requirement |
| Signed updater | `installer/internal/update/*`, `installer/cmd/setup/updater_windows_test.go`, `tests/test_updater_contract.py` | Stable semantic versions, API parsing, signature and descriptor verification, limits/timeouts/redirects, daily deferral, path-scoped mutex, legacy-manifest migration, updater launch contract |
| Recurring EA update opportunities | `tests/test_native_update_schedule.py` | Actual scheduler body: ten-second initial boundary, hourly recurrence, disabled/uninitialized gates and failed-launch throttling; process launch is a stub |
| Production-function risk/controller | `tests/test_native_risk_trade.py`, `tests/test_native_controller.py`, `tests/test_native_full_controls.py` | Extracted production bodies, stop-limit fill, overnight sessions, readiness, inventory failure, numeric replacement, render retry, explicit Full choices and safe SL-batch collection |
| Production-function UI | `tests/test_native_ui.py` | Measured field/selection/caret bounds, pagination, missing-data states, DPI resources, contrast and canvas-allocation failure |
| Production-function plan/marker regression | `tests/test_native_plan_preservation.py`, `tests/test_native_exposure_review.py` | Per-symbol and legacy round trips, actual controller transitions, fixed protective prices across mode cycles, invalid saved plans, unsupported Pending recovery, separated handles and label lanes at supported scales |
| Current-source installer | `tests/conftest.py`, `installer/cmd/setup/audit_regression_windows_test.go` | Synthetic nontrading payload, no historical build dependency, migration collision, rollback restoration failure, worker cleanup and path linkage |

Native function fixtures compile extracted MQL bodies as C++17 with deterministic platform stubs. MQL array signatures/declarations receive documented syntax-only adapters where needed. They are stronger than duplicated reference models but do not emulate UTF-16, MT5's event queue, native canvas rasterization or broker behavior. Require g++ and inspect skipped tests explicitly. Fresh installer PE tests require Go, Git Bash and pytest; they do not require a private signing key.

Automated command:

```bash
./scripts/run_offline_tests.sh
```

## 3. Native compile gate

For an authorized release, run `scripts\build_release.ps1`. For a no-install/no-sign audit, copy EA sources to an ignored audit-owned directory and invoke MetaEditor with `/compile` and `/log`, hidden. Do not use a release workflow that reads production signing keys or replaces canonical/release artifacts. Acceptance requires:

- MetaEditor result exactly `0 errors, 0 warnings`;
- nonempty EX5 at the documented output path;
- staged/canonical equality only when that packaging operation was actually performed;
- no unexpected compiler diagnostic in the full log.

## 4. Manual MT5 calculation matrix

For every case, record symbol, account currency, symbol properties, configured values, expected calculation, displayed result, and pass/fail.

1. Long and Short Instant.
2. Buy Limit, Buy Stop, Sell Limit, Sell Stop.
3. Risk authority: percentage and money.
4. Account basis: Equity, Balance, Manual.
5. Live equity/balance changes under each authority.
6. Manual value persistence across mode switches and terminal restart.
7. Commission zero in the current UI. Nonzero engine cases require fixtures; no visible commission control is provided.
8. Forex, metal, index, energy, and exchange-style demo symbols.
9. A symbol whose profit currency differs from account currency.
10. Distinct digits, tick sizes, volume steps, volume minima/maxima, and volume limits.
11. Below-minimum, above-maximum, and aggregate-limit requests.
12. Stop distance zero, one tick, large, crossed, and inside stops/freeze levels.
13. Missing quote, stale quote, and invalid/unavailable symbol properties where reproducible.
14. Independent comparison of downward rounding and the explicit minimum-volume exception, where actual risk may exceed target.

## 5. Manual editing matrix

Test every editable field:

1. One click focuses the intended field.
2. Type `1`, replace with `2`, and observe dependent values update on that same edit.
3. Decimal point; decimal comma; Backspace; Delete; Ctrl+A replacement; Left/Right; Shift selection; Home/End.
4. Enter commit; Escape rollback.
5. Empty, standalone separator, standalone sign, invalid character, very large finite value, NaN-like, infinity-like.
6. Commit by another field, another control, blank panel, and outside panel.
7. Quote updates while editing do not steal focus or overwrite raw text.
8. Repeated entry and exit leaves no duplicate caret, selection, edit rectangle, or residual object.

## 6. Manual chart interaction matrix

1. Single click, double-click, and drag each owned horizontal line. Price must not change.
2. Press every visible part of each handle once and drag. No preselection or double-click.
3. Verify line and handle remain continuously coupled during fast and slow movement.
4. Verify each handle changes only its own level and updates the field/calculation immediately.
5. Hide lines and move each level outside the viewport. Handles must disappear.
6. Resize, maximize, dock, zoom, scroll, scale, change timeframe, and change symbol. Handles must remain attached when in view.
7. Place broker trade levels or ordinary chart objects under the panel/handles. Interactions beginning over LotCraft must not move them.
8. Verify normal broker/object interaction outside LotCraft still works after release and after EA removal.
9. Drag the panel inside and outside its starting bounds, including pointer exit and release. Only the panel moves and chart properties restore.
10. Repeated double-clicks never expose an MT5 object-selection border.

## 7. Control and lifecycle matrix

1. Exercise each listed control once and confirm exactly one intended effect.
2. Confirm no unlisted visible control exists in full or mini mode.
3. Toggle confirmation, line visibility, and full/mini at least 20 times each.
4. Hold every stepper through every acceleration tier and release inside, outside the control, and outside the chart.
5. Attach/remove at least 20 times.
6. Change symbol and timeframe repeatedly.
7. Apply templates and restart terminal.
8. Run multiple instances on different charts and verify independent object/state namespaces.
9. Remove the EA and inspect object list plus changed chart settings.
10. Lose/regain quote connection and toggle terminal/EA trading permissions.

## 8. Demo trading safety matrix

Use minimum practical demo volume or a mocked request gateway. Never use a live account.

1. Valid Long and Short market requests.
2. All four valid pending subtypes.
3. New-order confirmation approve/cancel, refreshed valid quote with no second confirmation, and refreshed invalid request with no send. Separately test changed SL-batch target-set confirmation and second-set-change abort.
4. Rapid double-click and held input while submission starts.
5. Requote, stale price, invalid stops, invalid volume, unsupported fill, market closed, no connection, trading disabled, and explicit server rejection.
6. Confirm reported retcode and IDs match the terminal/server result.
7. Move SLs with zero, one, and multiple eligible positions/orders.
8. Hedging and netting accounts.
9. One forced modification failure among otherwise eligible targets.
10. Verify no request changes another symbol, TP, entry, volume, or unrelated order property. SL batches intentionally include both directions when eligible.

## 9. Installer and release matrix

1. Interactive install into a normal terminal data directory.
2. Quiet install with explicit terminal and payload paths.
3. Multiple discovered terminals.
4. Invalid directory and directory without MT5 markers.
5. Dedicated-path upgrade over a prior LotCraft version.
6. Existing unrelated files in the LotCraft directory.
7. Junction, symbolic link, and mount-point cases with accepted and rejected resolved destinations.
8. Confirm no old Position Sizer path changes.
9. Uninstall from the copied uninstaller and from setup `-uninstall` mode.
10. Tampered EX5, updater, uninstaller, or manifest must fail closed and preserve unrelated files.
11. Verify migration from the legacy three-file v1.0.0 manifest to the four-file updater-aware manifest.
12. Inject failure at every staged commit position. Verify restoration when possible and explicit recovery errors with retained backups when restoration fails. Per-file renames do not prove crash-atomicity.
13. Verify updater mutex exclusion, 24-hour attempt throttling, 24-hour same-version deferral, stable-only selection, API parsing, redirects, timeouts, response limits, signatures, sizes, and hashes. Verify a launch opportunity after ten seconds and hourly while attached, no per-tick failure retries, and no launch in Strategy Tester. Old 1.2.0 activation needs a normal reattachment or restart.
14. Verify canonical, staged, installed, and installer SHA-256 values plus signed bootstrap metadata.

## 10. Long-duration and performance checks

- Rapid panel drag for at least 60 seconds.
- Rapid handle drag while ticks arrive.
- Continuous stepper acceleration on each stepper.
- Editing while ticks arrive.
- Idle run for at least four hours.
- Review Experts and Journal logs for initialization failures, repeated floods, array errors, zero division, access violations, invalid pointers, object leaks, undeleted objects, and duplicate requests.

## 11. Symbol transition, pending stability, and marker ownership regression

1. On USDJPY M15 select Long/Pending, place a valid E/S plan, then replace the symbol with a previously unseen USTEC. The first coherent render must contain only USTEC-scaled prices. A previously saved USTEC restores its own Direction/mode/Entry/SL/TP instead. Positive size remains conditional on valid broker/account data.
2. Repeat for Short/Instant, then return to USDJPY. Its last chosen SL/TP and mode must be restored. Never reuse another symbol's numbers. Repeat EURUSD/gold and index round trips.
3. Change timeframe on one symbol and return. Entry, SL, TP, Direction, and mode must remain the exact same-symbol plan after tick normalization. No reanchor is allowed for timeframe, zoom, or resize alone.
4. On US30 start with a valid Long Instant plan, record SL/TP, then alternate Pending/Instant at least 30 times. SL/TP must remain exact. Instant Entry follows the quote; Pending Entry remains conditional on its quote leg. Confirm a quote crossing the saved SL disables execution without moving it.
5. Repeat the Instant-to-Pending test for Short and with Limit disabled/Stop enabled. If neither pending subtype is supported, the previous complete Instant model and calculation must remain unchanged and a capability error must be shown.
6. Put E/S/T prices close enough that their original hit rectangles would overlap. Handles must separate horizontally and retain exact price/Y. Each handle must select its own level. S retains first overlap priority when space is insufficient. Position-loss labels must not cover these handles; details remain available when no lane fits.
7. Repeat the basic checks in Full, Compact, and Mini views and both themes. No layout, editor, stepper, panel-drag, or line-flicker behavior may regress.

## 12. SL exposure and adaptive UI acceptance matrix

| Dimension | Required cases |
|---|---|
| Theme and mode | Dark and light; Full, Compact, and Mini. Summary is present only in Full and Compact; persisted details remain bounded in every mode. |
| DPI geometry | Source-calculated layouts at 96, 120, 144, and 192 DPI; chart widths immediately above and below each base panel width. |
| Exposure contents | Zero positions; one Long; one Short; profitable trailing SL; missing SL; unavailable projection; pending order; mixed symbols; zero equity. |
| Row volume | One, eight, nine, and 50 exposure rows; scrolling remains clamped and deterministic. |
| Label collisions | Eight open-position labels at the same SL; labels beside the S marker, main panel, sidecar, chart top, and chart bottom. S keeps input priority. |
| Concurrent activity | Drag panel and S/E/TP while exposure becomes dirty; no exposure calculation or collision layout runs in the pointer hot path. |
| Lifecycle | Change symbol and timeframe while details are open; current-chart scope refreshes without stale-symbol values or off-chart surfaces. |
| Trading regression | Confirmation behavior, final trade control, calculated volume, pending/instant behavior, and `Move SLs to line` remain unchanged. |

Automated evidence covers arithmetic, sorting, incomplete-data behavior, source ownership, persistence allowlisting, canvas count, hit-test precedence, DPI-scaled tokens, and compile contracts. Actual MT5 appearance and broker interaction remain user-run manual acceptance; this implementation task intentionally performs no live MT5 UI or live-trading verification.

Current command results belong in [audit verification](AUDIT_VERIFICATION_2026-09-09.md), not in this acceptance checklist. Record blocked and skipped cases without converting them into passes.
