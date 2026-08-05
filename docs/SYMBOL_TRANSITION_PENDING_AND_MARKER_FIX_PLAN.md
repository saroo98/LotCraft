# LotCraft Symbol Transition, Pending Stability, and Marker Ownership Completion Plan

Status: implemented for LotCraft 1.1.0; automated and native build gates completed, user visual acceptance pending

Target: current `main` worktree at commit `6423dd2`, including the three existing uncommitted default-SL-gap changes

Scope: fix symbol-change planning, overlapping E/S marker ownership, and Instant-to-Pending sizing instability without changing unrelated UI, trading, installer, updater, or risk behavior

## 1. Execution mandate

Implement this plan as one coherent defect fix. Do not stop after masking one screenshot symptom. The completed result must satisfy every invariant and acceptance case in this document.

The implementation agent must follow these rules:

1. Do not ask the user to choose an algorithm or clarify expected behavior. All required behavioral decisions are defined below.
2. Preserve the existing uncommitted changes in:
   - `MQL5/Experts/LotCraft/PS_Risk.mqh`
   - `tests/test_calculation.py`
   - `tests/test_static_contract.py`
3. Treat those changes as part of the fix. Do not reset, replace, or reimplement them in a way that drops the `0.2%` price-relative minimum default SL distance.
4. Do not alter panel dimensions, fonts, colors, themes, field editing, stepper acceleration, confirmation behavior, magic number, Move SLs behavior, installer behavior, updater behavior, or trading request semantics except where this plan explicitly requires a controller-state correction.
5. Do not place a live-account trade. Runtime trade checks, if any, must use a demo account or stop before `OrderSend`.
6. Do not commit, push, publish a release, or modify the GitHub repository unless the user explicitly requests that separately.
7. Do not claim the defects are fixed from static tests alone. Complete the offline suite and native compile gates. The user retains final live visual verification, per the standing instruction not to control their active MT5 UI.

## 2. User-visible defects to eliminate

### 2.1 USDJPY to USTEC symbol replacement corrupts the planning layout

Starting state from the supplied USDJPY screenshot:

- Direction: Long
- Mode: Pending
- Entry and SL are visibly and numerically separated.
- The setup has a nonzero broker-valid size.

After dragging USTEC onto the same chart, the supplied screenshots show:

- Pending unexpectedly becoming Instant.
- SL being regenerated only a few points from Entry.
- E and S occupying overlapping hit regions.
- The visible red S can appear to be on top, but dragging that area moves E.

Required outcome:

- The selected Direction and Instant/Pending mode survive a symbol change.
- Prices from the old symbol are never reused numerically on the new symbol.
- A fresh, coherent Entry/SL plan is generated on the new symbol in one transaction.
- Automatically generated Entry and SL cannot normalize to the same tick.
- Their markers are visibly separated under a normal current-price viewport.
- If their hit rectangles overlap for any reason, S owns the overlap and dragging changes SL, never Entry.

### 2.2 Instant to Pending temporarily produces Size 0 and `Cannot trade`

The supplied US30 screenshots show this sequence:

1. Instant is valid with a nonzero size.
2. Pending is selected.
3. Entry remains at or almost at the live quote.
4. Pending-order inference alternates between ambiguous, valid, and ambiguous as the quote moves.
5. The UI alternates between Size 0 / `Cannot trade` and a valid order.

Required outcome:

- Switching from Instant to Pending must create a broker-valid pending Entry away from the live quote before the first recalculation or render.
- The existing SL must not move during this mode switch.
- The initial pending subtype must be deterministic and supported by the symbol.
- A normal amount of quote movement inside the planned safety buffer must not make the setup oscillate between valid and invalid.
- There must be no intermediate render containing Size 0 or `Cannot trade` caused solely by the mode transition.

### 2.3 E captures input before S in an overlapping marker region

Required outcome:

- Stop marker priority is higher than Entry marker priority both visually and in custom hit testing.
- Pointer capture is bound to the level selected on mouse-down and cannot switch levels during the same drag.
- The price relationship still determines Long or Short exactly as before. “S on top of E” means visual and input z-order, not that SL must always be a numerically higher price.

## 3. Confirmed root causes

These are established from the current source and must guide the fix.

### Root cause A: symbol replacement can use the deinitialize/reinitialize path

`LotCraft.mq5::PS_RefreshMarket()` contains a symbol-change reanchor path, but dragging a symbol onto an MT5 chart can reinitialize the EA. On reinitialization:

1. `PS_ModelInitialize()` resets Direction to Long and mode to Instant.
2. `PS_PersistenceLoad()` restores Direction, mode, Entry, SL, and TP only when `plansym` matches the current symbol.
3. A new symbol intentionally fails that same-symbol test.
4. The new model therefore keeps the default Instant mode.
5. Until the current uncommitted work is incorporated, the initialization SL distance can be only a broker/tick minimum and can appear almost coincident with Entry on a high-priced index.

The in-process symbol-change logic and the reinitialization logic therefore produce different state.

### Root cause B: Instant-to-Pending changes only the enum

`PS_Risk.mqh::PS_ModelChangeOrderMode()` currently assigns `PS_ORDER_PENDING` without moving Entry away from the executable quote. `PS_RiskResolveOrder()` correctly rejects a Pending Entry that is not clearly below or above the quote. The live quote then moves around that unchanged Entry, causing the observed valid/invalid oscillation.

Size 0 is a downstream projection of an invalid `PSCalcResult`; it is not a volume-rounding defect.

### Root cause C: handle hit testing is Entry-first

`PS_UI.mqh::PS_UIHitHandle()` iterates the level array from index `0` to `2`. The enum/array ordering places Entry before Stop, so an overlapping region returns Entry first.

All handle canvas objects also receive the same `OBJPROP_ZORDER` value, so visual order and input order are not explicitly aligned.

### Root cause D: transitions are not expressed as atomic candidate-state commits

The current controller mutates authoritative fields directly and then recalculates. That is safe for many individual edits, but symbol and order-mode transitions modify several mutually dependent fields. They need candidate construction, validation, and one final commit so the UI never sees a half-transitioned model.

## 4. Behavioral contract and invariants

The implementation is complete only when all of these invariants hold.

### 4.1 Model invariants

1. `PSModel` remains the sole authoritative planning state.
2. A model committed for a ready symbol always uses that symbol's digits, tick size, quote, stop/freeze constraints, and pending-order capabilities.
3. An automatically generated Long plan has `SL < effective Entry` by at least the required normalized level gap.
4. An automatically generated Short plan has `SL > effective Entry` by at least the required normalized level gap.
5. Automatic normalization may increase a protective distance but may never collapse it to equality.
6. Switching symbols preserves Direction and order mode but does not preserve old-symbol numeric prices.
7. Changing timeframe on the same symbol preserves Direction, mode, Entry, SL, and enabled TP exactly after normalization to the same symbol lattice.
8. Switching Instant to Pending preserves the existing SL exactly.
9. Switching Pending to Instant may retain the current existing translation behavior that moves the bracket by the Entry delta, provided all final prices remain valid.
10. A failed candidate transition leaves the complete previous model unchanged.

### 4.2 Pending-plan invariants

1. Pending Entry is separated from the relevant live quote by more than the broker's required distance plus a safety buffer.
2. Pending Entry and SL are separated by more than the broker's required protective distance plus a safety buffer.
3. The initial pending subtype is inferred unambiguously before recalculation.
4. Prefer a Limit subtype that places Entry between the live quote and SL when the symbol supports it and enough room exists.
5. If that Limit geometry cannot fit, use a supported Stop subtype on the other side of the quote while preserving SL.
6. If TP is enabled and remains valid after the new Entry is selected, preserve it. If Entry movement would invalidate TP, translate TP by the Entry delta while preserving its original distance and correct profit side.
7. If the symbol supports neither required pending subtype, do not mutate the model. Report the broker capability error. This is a genuine symbol restriction, not a `Cannot trade` flicker.

### 4.3 Rendering and pointer invariants

1. S has higher hit-test priority than E.
2. S has a higher chart-object click z-order than E.
3. S is painted after E when both handles occupy overlapping pixels.
4. Once mouse-down captures Stop, all queued motion and the final release update Stop only.
5. No quote refresh, chart-change event, or line maintenance pass may replace an active capture's level identity.
6. Lines and handles are rendered only after the transition candidate is committed and recalculated.

### 4.4 Calculation and UI invariants

1. A successful mode or symbol transition performs one coherent recalculation from the committed model.
2. No intermediate calculation result is rendered.
3. Normal quote refresh may update an Instant effective Entry, but it must not alter SL.
4. A Pending Entry remains fixed after construction unless the user edits or drags it.
5. A genuinely reached/crossed pending price may eventually become invalid under broker rules. The fix must not hide this safety condition or silently chase the quote. The defect being removed is the artificial quote-equal Entry created by the mode transition.

## 5. Files to change

### Required source changes

- `MQL5/Experts/LotCraft/PS_Risk.mqh`
  - Keep and integrate `PS_ModelDefaultLevelDistance()`.
  - Add direction-aware normalized gap helpers.
  - Add fresh-symbol-plan and Instant-to-Pending candidate builders.
  - Make order-mode changes atomic and failure-aware.

- `MQL5/Experts/LotCraft/PS_Persistence.mqh`
  - Restore Direction and order mode independently of same-symbol price restoration.
  - Return whether same-symbol planning prices were loaded.
  - Preserve the existing key format and backward compatibility.

- `MQL5/Experts/LotCraft/LotCraft.mq5`
  - Unify initialization and live symbol-change behavior.
  - Commit symbol and order-mode transitions once.
  - Abort stale editor/pointer state on chart context replacement.
  - Avoid rendering an intermediate invalid calculation.

- `MQL5/Experts/LotCraft/PS_UI.mqh`
  - Give Stop explicit visual and hit-test priority over Entry.
  - Keep handle rendering deterministic when rectangles overlap.

### Required test changes

- `tests/reference_model.py`
  - Add pure reference helpers for fresh-symbol plan construction and Instant-to-Pending conversion.

- `tests/test_calculation.py`
  - Retain the current uncommitted default-gap tests.
  - Add symbol-transition and pending-stability fixtures.

- `tests/test_static_contract.py`
  - Replace obsolete assertions that require symbol reanchoring to ignore order mode.
  - Add contracts for initialization symmetry, atomic transitions, persistence separation, and Stop-first handle ownership.

### Documentation updates after implementation

- `docs/ARCHITECTURE.md`
  - Document cross-symbol preference restoration versus same-symbol price restoration.
  - Document atomic planning transitions and Stop-first overlap ownership.

- `docs/TEST_PLAN.md`
  - Add the exact USDJPY to USTEC and US30 Instant-to-Pending regression scenarios.

- `docs/TRACEABILITY.md`
  - Map each new invariant and test to the modified functions.

Do not change installer or updater files for this defect.

## 6. Detailed implementation sequence

### Phase 0: preserve the current worktree

1. Record `git status --short --branch`.
2. Record `git diff --` for the three pre-existing modified files.
3. Do not use reset, checkout, restore, clean, or a formatter over unrelated files.
4. Confirm the existing helper still contains all three components:
   - broker protective distance plus one tick;
   - `100 * tick_size`;
   - `reference * 0.002`.
5. Treat generated files under `build/`, `release/`, and `artifacts/` as ignored build output. Do not add them to Git.

### Phase 1: separate persistent preferences from same-symbol prices

Modify `PS_PersistenceLoad()` to return a Boolean named for its actual meaning, such as `same_symbol_plan_loaded`.

Required load order:

1. Load non-price preferences exactly as today: account basis, manual amount, risk authority/values, confirmation, view, theme, and line visibility.
2. Load Direction and order mode whenever their persisted values are valid, even when `plansym` differs from the current symbol.
3. Evaluate `same_planning_symbol`.
4. Read Entry, SL, and TP into local variables only when `same_planning_symbol` is true.
5. Assign all three price fields together only when the complete same-symbol set is structurally usable. Entry and SL must both be positive finite values; TP may be zero.
6. Return true only after that complete local set has been assigned.
7. If a legacy or partial same-symbol set is corrupt, return false and let the fresh-plan builder repair it. Do not mix one restored price with two defaults.

Keep `PS_PersistenceSave()` compatible with the current keys. Direction and mode remain written with the planning snapshot. Moving their reads outside the symbol-match block is sufficient for backward compatibility and avoids a persistence schema migration.

Expected lifecycle result:

- Timeframe change on the same symbol: true, exact planning prices restored.
- Symbol change to a different symbol: false, Direction and mode restored, old prices ignored.

### Phase 2: create direction-aware normalization primitives

Keep `PS_ModelDefaultLevelDistance()` as the base economic/broker gap. Add helpers that convert a required distance to an integer number of symbol ticks and place a price outward from a reference.

Required behavior:

1. Compute tick count with ceiling, never nearest rounding:
   - `ticks = ceil(required_distance / tick_size)`.
2. Enforce at least one tick.
3. Long protective placement subtracts the integer tick distance.
4. Short protective placement adds the integer tick distance.
5. Normalize once to symbol digits after tick-lattice placement.
6. Recheck strict ordering after normalization.
7. If ordering or the required gap was lost, move outward one additional tick and recheck.
8. Fail without mutation if a positive finite result cannot be produced.

Add a visual fresh-plan distance helper rather than changing the meaning of `PS_ModelDefaultLevelDistance()`:

```text
base_gap = max(
  protective_distance + tick_size,
  100 * tick_size,
  abs(reference) * 0.002
)

visual_entry_sl_gap = 0 unless the viewport is coherent and contains reference
visual_entry_sl_gap = viewport_span * (34 / chart_height) when coherent

instant_reference_sl_gap = max(
  base_gap,
  visual_entry_sl_gap,
  3 * pending_leg_gap
)

pending_reference_sl_gap = max(
  base_gap,
  visual_entry_sl_gap / 0.60,
  3 * pending_leg_gap
)
```

Use `34` pixels because the marker is 26 pixels tall and needs a visible margin. The pending formula divides by `0.60` because the preferred pending Entry consumes approximately 40% of the reference-to-SL distance, leaving 60% for the visible Entry-to-SL separation. The viewport contribution is for automatically created/reanchored plans only. User-dragged levels must remain where the user puts them.

Define:

```text
spread = max(0, ask - bid)
pending_leg_gap = max(
  protective_distance + 4 * tick_size,
  8 * tick_size,
  2 * spread
)
```

The exact expressions must be applied on the tick lattice and revalidated after normalization.

### Phase 3: build one coherent fresh plan for the current symbol

Replace the current partial new-symbol initialization/reanchor behavior with a mode-aware helper, for example:

```text
bool PS_ModelBuildFreshSymbolPlan(
  PSModel &model,
  const PSMarketSnapshot &market,
  const double visible_min,
  const double visible_max,
  const int chart_height,
  string &error
)
```

Implementation requirements:

1. Build into a local candidate model. Do not mutate `model` until all required prices are valid.
2. Require a synchronized symbol, valid quote, positive tick size, and valid digits.
3. Select executable reference:
   - Long: Ask.
   - Short: Bid.
4. Compute the mode-appropriate reference-to-SL gap from Phase 2.
5. Generate SL outward from the executable reference:
   - Long: reference minus required gap.
   - Short: reference plus required gap.
6. If mode is Instant:
   - Entry equals the normalized executable reference.
   - SL is the outward price.
7. If mode is Pending, generate an unambiguous supported subtype before commit:
   - Prefer Buy Limit for Long and Sell Limit for Short when Limit orders are supported.
   - Put Entry between reference and SL.
   - Use approximately 40% of the total reference-to-SL gap for reference-to-Entry, clamped so both pending legs remain at least `pending_leg_gap`.
   - If Limit is unsupported or cannot satisfy both legs, use Buy Stop for Long or Sell Stop for Short when Stop orders are supported, placing Entry beyond the quote by at least `pending_leg_gap`.
   - If neither construction is supported, fail with a capability-specific error and leave the old model unchanged.
8. Preserve only whether TP was enabled across a different-symbol reanchor. Generate a new-symbol TP on the correct profit side using at least `required_gap` from the new effective Entry. Never reuse the old symbol's TP number.
9. Run the same order-geometry and protective-price validation used by normal calculation against the candidate.
10. Commit Entry, SL, TP, and one revision increment only after candidate validation succeeds.

Do not clamp a price toward Entry merely to keep it in the viewport. If viewport data is stale or cannot fit the required gap, ignore the viewport contribution and use the broker/tick/relative gap. Price validity and non-overlap take priority over an unreliable viewport sample.

### Phase 4: unify OnInit and live symbol-change transitions

#### OnInit path

Use this exact order:

1. Acquire market snapshot.
2. Initialize model defaults.
3. Build persistence base.
4. Load preferences, Direction, mode, and optional same-symbol plan. Capture the Boolean return.
5. Apply the existing forced zero-commission behavior.
6. If a complete same-symbol plan was loaded:
   - Keep it.
   - Synchronize Instant Entry only if mode is Instant.
   - Perform structural validation only: finite values, positive Entry/SL, tick-lattice normalization, and SL on the correct side of Entry.
   - Do not reanchor a structurally valid Pending plan merely because the live quote has since reached or crossed its Entry. That is a legitimate current-market invalid state, and preserving the user's same-symbol plan takes priority on a timeframe change.
   - Fall back to a fresh plan only when the stored prices themselves are corrupt or internally contradictory.
7. If no same-symbol plan was loaded:
   - Read chart size and viewport once.
   - Call `PS_ModelBuildFreshSymbolPlan()` using the restored Direction and mode.
8. Create UI objects and timer.
9. Recalculate once.
10. Mark initialized and render once.

This makes a symbol-drag reinitialization produce the same result as an in-process symbol change.

#### `PS_RefreshMarket()` path

For a detected different symbol:

1. Save the old planning snapshot using the old `g_market` and current model before copying the new market snapshot.
2. End or cancel any active editor safely. Do not commit old-symbol raw text into the new-symbol model.
3. Abort pointer capture and restore chart interaction guards.
4. Copy the new market snapshot.
5. Build a complete fresh-symbol candidate while preserving current Direction and mode.
6. Commit only if the candidate succeeds.
7. Update `g_active_symbol` only after the new-symbol model is coherent.
8. Recalculate once and mark both panel and lines dirty.
9. Render once after returning to the normal render path.

For the same symbol:

- Keep the existing initial-price repair only for truly absent values.
- Never reanchor SL because of a timeframe, zoom, resize, or ordinary chart-change event.

If the first new-symbol market snapshot has no valid quote, keep the transition pending and retry on timer without showing old-symbol lines on the new chart. Do not commit zeros. Once a valid snapshot arrives, build and commit exactly once.

### Phase 5: make Instant-to-Pending an atomic valid transition

Change `PS_ModelChangeOrderMode()` from an unconditional `void` mutation to a failure-aware candidate transition, such as:

```text
bool PS_ModelChangeOrderMode(
  PSModel &model,
  const PSMarketSnapshot &market,
  const PSOrderMode new_mode,
  string &error
)
```

For Instant to Pending:

1. Copy the complete model into a local candidate.
2. Compute executable reference, `pending_leg_gap`, and existing reference-to-SL room.
3. Do not change candidate SL.
4. Prefer a supported Limit subtype:
   - Long: Entry below Ask and above SL.
   - Short: Entry above Bid and below SL.
   - Choose a tick-normalized point around the midpoint of reference and SL, then clamp it so both legs meet `pending_leg_gap`.
5. If there is not enough room for a valid Limit subtype, choose a supported Stop subtype beyond the quote by at least `pending_leg_gap` while retaining SL.
6. Preserve TP if valid relative to the candidate Entry. Otherwise translate TP by the Entry delta, preserving distance and correct side.
7. Validate candidate pending subtype, quote distance, SL relationship, TP relationship, and symbol capabilities.
8. Set `order_mode = PS_ORDER_PENDING` only on the candidate.
9. Commit all candidate fields and increment revision once.
10. Return true.

For Pending to Instant:

- Keep the existing bracket-translation concept.
- Build and validate it as a candidate first.
- Commit once or leave the prior Pending model unchanged.

Update `LotCraft.mq5::PS_Action(PS_CTRL_ORDER_MODE)`:

1. Commit an active editor first if required.
2. Call the failure-aware mode transition.
3. On success, clear transient status, save state, and call `PS_Recalculate(false)` once.
4. On failure, retain the old mode and prices, display the precise error, and render the unchanged valid state.
5. Never assign mode separately in the controller.

Dragging E while Instant must continue to switch to Pending automatically. Route that path through the same pending candidate logic, then replace the candidate Entry with the final dragged price. Validate/recalculate at drag completion. Do not introduce a separate second implementation of mode conversion.

### Phase 6: make S the owner of overlapping handle pixels

Modify `PS_UI.mqh` as follows:

1. Replace array-index-order hit testing with explicit priority:
   1. Stop.
   2. Entry.
   3. Take-profit.
2. Return Stop whenever both Stop and Entry rectangles contain the pointer.
3. Assign distinct object click z-orders in `PS_UIEnsureHandleCanvas()`:
   - Stop: highest.
   - Entry: middle.
   - Take-profit: lowest.
4. Update existing objects' z-order as well as newly created objects. Do not rely on creation-time assignment only.
5. Render/update canvases in deterministic paint order: Take-profit, Entry, Stop.
6. Preserve the current visible letters, sizes, colors, and marker geometry.
7. Keep the capture enum fixed after `PS_MousePress()`. `PS_MouseMoveCaptured()` and `PS_MouseRelease()` must consume the captured enum and must not hit-test again.
8. Add a focused assertion or helper that documents the distinction between visual overlap priority and Long/Short price inference.

### Phase 7: prevent intermediate invalid projections

1. Symbol and mode helpers must not set `g_ui.dirty` or call render functions internally.
2. Controller code must not call `PS_Recalculate()` until the complete candidate is committed.
3. Do not call render between enum assignment and price assignment.
4. On a successful transition, clear the old `PSCalcResult` only inside the single final `PS_RiskCalculate()` call.
5. On a failed transition, retain and rerender the previous coherent model/calculation result with a transient error status. Do not replace the trade button with Size 0 unless the retained model is independently invalid.
6. Add diagnostics under the existing diagnostics compile switch for:
   - transition start;
   - old and new symbol;
   - preserved Direction/mode;
   - candidate Entry/SL/TP;
   - chosen pending subtype;
   - transition commit or rejection;
   - final calculation validity and volume.
7. Rate-limit repeated waiting-for-quote messages. Do not add noisy release logging.

## 7. Automated regression tests

### 7.1 Reference-model tests

Extend `tests/reference_model.py` with pure functions mirroring only the new deterministic geometry. The reference code must not copy implementation text blindly; it should independently express the same contract.

Add fixtures for at least:

| Fixture | Digits/tick | Purpose |
|---|---:|---|
| USDJPY around `157.5` | broker fixture | Source symbol and three-digit normalization |
| USTEC around `29479.5` | broker fixture | High-priced index symbol transition |
| US30 around `54423.6` | broker fixture | Instant-to-Pending stability |
| EURUSD around `1.13843` | `0.00001` | Fine tick lattice |
| BTC-like symbol around `65000` | broker fixture | Large price-relative default gap |

### 7.2 Required calculation/controller cases

Add tests with descriptive names covering all of the following:

1. Fresh Long Instant plan: SL is below Entry by the normalized required gap.
2. Fresh Short Instant plan: SL is above Entry by the normalized required gap.
3. Fresh Long Pending plan: supported Buy Limit is unambiguous and SL is valid.
4. Fresh Short Pending plan: supported Sell Limit is unambiguous and SL is valid.
5. Limit unsupported, Stop supported: correct fallback subtype is chosen.
6. Neither subtype supported: transition fails without changing the original model.
7. USDJPY Pending Long to USTEC preserves Pending and Direction but replaces all numeric prices.
8. USTEC fresh automatic Entry/SL cannot normalize to equality.
9. Automatic USTEC Entry/S spacing meets the 34-pixel-derived gap when viewport data is coherent.
10. Same-symbol timeframe reinitialization restores exact planning prices.
11. Different-symbol initialization ignores old Entry/SL/TP while still loading Direction and mode.
12. Instant Long to Pending preserves SL exactly and creates a valid nonzero-size plan.
13. Instant Short to Pending preserves SL exactly and creates a valid nonzero-size plan.
14. Quote samples throughout half of the pending safety buffer keep the initial pending subtype valid and keep volume positive.
15. Candidate normalization at half-tick boundaries moves outward rather than collapsing Entry and SL.
16. Failed mode conversion leaves order mode, Entry, SL, TP, revision, and previous calculation unchanged.
17. TP stays unchanged when valid and translates only when required.
18. Dragging Entry from Instant routes through Pending conversion once.
19. Dragging Stop across Entry still performs the existing immediate Long/Short alignment.

### 7.3 Static source contracts

Update `tests/test_static_contract.py` so it proves structural properties rather than preserving the old bug.

Required assertions:

1. `PS_ModelDefaultLevelDistance()` remains used by initialize, initial-price repair, fresh-symbol construction, and direction change.
2. Persistence reads Direction and order mode outside the same-symbol price block.
3. Persistence returns whether a complete same-symbol plan was loaded.
4. `OnInit()` calls the same fresh-symbol-plan helper used by live symbol replacement when no same-symbol prices are loaded.
5. `PS_RefreshMarket()` saves old-symbol state before copying the new snapshot.
6. New-symbol commit occurs before `g_active_symbol` is updated.
7. Order-mode change uses a local candidate and returns success/failure.
8. Controller performs one recalculation after a successful mode transition.
9. `PS_UIHitHandle()` checks Stop before Entry.
10. Stop z-order is greater than Entry z-order.
11. Capture motion does not call `PS_UIHitHandle()` again after mouse-down.
12. No source path renders between partial mode-transition assignments.

Remove or rewrite the existing assertion that `PS_ModelReanchorForSymbol()` must not inspect `model.order_mode`; the new fresh-plan builder must be mode-aware.

### 7.4 Existing suite preservation

All existing tests must continue to cover:

- risk sizing and minimum-volume behavior;
- precise numeric editing and double-click selection;
- accelerated steppers;
- direction alignment from SL movement;
- Move SLs scope and safety;
- confirmation and zero magic number;
- UI modes/themes/layout contracts;
- installer, updater, signing, and privacy contracts.

Do not weaken unrelated assertions to make the suite pass.

## 8. Native build and validation sequence

Run from:

```text
F:\Giuthub Projects\Experts\PashoolSizer-1.0.0-theme-work
```

### 8.1 Fast targeted loop

```powershell
py -3.11 -m pytest -q `
  tests/test_calculation.py `
  tests/test_static_contract.py
```

Run this after each coherent source phase.

### 8.2 Full offline validation

```powershell
py -3.11 -m pytest -q
Push-Location installer
go test ./...
go test -race ./...
go vet ./...
Pop-Location
git diff --check
```

Acceptance:

- Every Python test passes.
- Every Go test passes.
- Go race test passes.
- Go vet passes.
- `git diff --check` reports no whitespace errors.

### 8.3 Native MetaEditor compile

Use the repository release script and installed MetaEditor path:

```powershell
.\scripts\build_release.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
```

Acceptance:

- Exactly `0 errors, 0 warnings` in the compiler log.
- Canonical and staged EX5 hashes match.
- Release verification succeeds.
- The signing key remains only under `%LOCALAPPDATA%\LotCraft\Signing` and is never printed, copied into the repository, or included in evidence.

Do not publish the generated release.

### 8.4 Final diff review

Review:

```powershell
git status --short --branch
git diff --stat
git diff -- `
  MQL5/Experts/LotCraft/LotCraft.mq5 `
  MQL5/Experts/LotCraft/PS_Risk.mqh `
  MQL5/Experts/LotCraft/PS_Persistence.mqh `
  MQL5/Experts/LotCraft/PS_UI.mqh `
  tests/reference_model.py `
  tests/test_calculation.py `
  tests/test_static_contract.py `
  docs/ARCHITECTURE.md `
  docs/TEST_PLAN.md `
  docs/TRACEABILITY.md
```

Reject the implementation if it includes unrelated layout, installer, updater, or trade-execution changes.

## 9. User runtime acceptance matrix

The user performs this final visual check in MT5. The implementation agent must provide a build that has already passed all automated and compile gates above and must not control the user's active mouse or desktop.

### Scenario A: supplied USDJPY to USTEC reproduction

1. Open USDJPY M15.
2. Select Long and Pending.
3. Place E and S with a clearly valid Long separation.
4. Drag USTEC from Market Watch onto the same chart.
5. Observe the first rendered LotCraft state.

Pass conditions:

- Mode is still Pending.
- Direction is still Long.
- USTEC Entry and SL are based on USTEC, not USDJPY.
- E and S are distinct and visibly separated.
- SL is on the valid Long side of Entry.
- Size is nonzero when the broker/account constraints permit a trade.
- No frame shows the old USDJPY numbers on USTEC.

### Scenario B: overlapping marker input ownership

1. Place E and S close enough that their 36-by-26 hit rectangles overlap while their prices remain distinct.
2. Press in the overlapping area where S is visible.
3. Drag vertically.

Pass conditions:

- S remains visually on top.
- Only SL follows the pointer.
- E remains at its prior price unless Long/Short logic legitimately synchronizes Instant Entry to the quote.
- Capture does not switch to E during movement or release.

### Scenario C: US30 Instant to Pending

1. Open US30 M15 with a valid Long Instant setup and nonzero size.
2. Select Pending once.
3. Observe for at least ten seconds without touching Entry.

Pass conditions:

- Pending activates immediately.
- SL does not move.
- Entry moves to one deterministic valid pending level.
- The button immediately shows a concrete pending order and positive size.
- It does not alternate between `Cannot trade` and a valid order while the quote remains inside the safety buffer.

### Scenario D: reverse direction and mode coverage

Repeat Scenario C for Short, then repeat symbol replacement for both Instant and Pending.

Pass conditions:

- Long/Short SL-side rules remain correct.
- Pending subtype is correct for the selected direction and price side.
- Moving S across E still changes direction immediately.

### Scenario E: lifecycle coverage

1. Change M15 to H1 and back on the same symbol.
2. Change symbol twice in succession.
3. Return to the original timeframe.

Pass conditions:

- Timeframe changes do not relocate SL.
- Symbol changes produce fresh symbol-scaled prices once, not repeated jumps.
- No duplicate handles, stale lines, flicker loop, or stuck pointer guard appears.

### Scenario F: UI regression coverage

Repeat a basic check in Full, Compact, and Mini modes, and in both dark and light themes.

Pass conditions:

- No geometry or text alignment changes.
- No marker flicker regression.
- Fields, copy controls, steppers, theme toggle, and panel dragging retain current behavior.

## 10. Completion checklist

The task is finished only when every item below is true:

- [ ] Existing uncommitted default-gap work is preserved and integrated.
- [ ] Reinitialization and in-process symbol changes use the same fresh-plan algorithm.
- [ ] Direction and order mode survive a different-symbol change.
- [ ] Old-symbol numeric prices never appear on the new symbol.
- [ ] Same-symbol timeframe changes preserve exact planning prices.
- [ ] Fresh automatic SL cannot equal or visually sit on Entry under a coherent viewport.
- [ ] Instant-to-Pending preserves SL and commits a valid pending Entry atomically.
- [ ] No artificial Size 0 / `Cannot trade` oscillation occurs after mode selection.
- [ ] Stop owns every E/S overlap in paint order, z-order, and hit testing.
- [ ] Stop dragging cannot become Entry dragging mid-capture.
- [ ] Long/Short auto-alignment from SL position still works.
- [ ] Targeted Python tests pass.
- [ ] Full Python suite passes.
- [ ] All Go tests, race tests, and vet pass.
- [ ] MetaEditor reports exactly zero errors and zero warnings.
- [ ] Canonical/staged EX5 verification passes.
- [ ] Final diff contains no unrelated changes and no secrets/generated binaries.
- [ ] Documentation and traceability describe the final behavior.
- [ ] User runtime matrix is handed over clearly for final visual sign-off.

## 11. Explicit non-solutions

Do not use any of these shortcuts:

- Do not merely increase the old `100 * tick_size` constant.
- Do not hide `Cannot trade` while leaving the calculation invalid.
- Do not keep the previous valid size after the model becomes genuinely invalid.
- Do not move Pending Entry continuously with the quote.
- Do not reuse USDJPY price values on USTEC through scaling by digits alone.
- Do not fix marker ownership only by color or visual paint order; custom hit-test order must change.
- Do not disable Entry dragging.
- Do not make chart lines selectable as a replacement for handle dragging.
- Do not save prices globally without a same-symbol guard.
- Do not rebuild the entire UI tree during symbol changes or handle motion.
- Do not weaken broker-distance, pending-order, or protective-price validation.

## 12. Final implementation handoff format

When implementation is complete, report:

1. The root causes fixed in one short paragraph.
2. The exact source and test files changed.
3. Test counts and pass results.
4. MetaEditor error/warning result.
5. EX5 verification result.
6. Any live visual checks intentionally left to the user under the no-active-desktop-verification instruction.
7. A concise reproduction checklist containing Scenarios A, B, and C.

Do not say “fixed” unless the automated and compile gates were actually executed and passed. Do not say the live visual behavior was verified unless the user or an isolated QA environment actually performed it.
