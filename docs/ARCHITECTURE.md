# LotCraft 1.2.1 Architecture

## 1. Product boundary

LotCraft is a discretionary position-sizing and explicit order-entry Expert Advisor. It does not generate signals, autonomously decide to trade, trail stops, close positions, copy trades, or manage a portfolio. A new order can originate only from the main trade control. Existing stop losses can change only from `Move SLs to line`.

The implementation is independent of any Position Sizer product. Runtime objects, terminal global variables, log messages, source paths, binary paths, installer files, and uninstall ownership use LotCraft-specific names.

## 2. Module structure

| Module | Responsibility | Owned state or resources |
|---|---|---|
| `LotCraft.mq5` | Lifecycle, event routing, controller state machines, control dispatch, confirmation flow, refresh cadence | One authoritative `PSModel`, current market snapshot, calculation result, editor state, pointer state, UI state |
| `PS_Types.mqh` | Identity constants, enums, domain records, finite checks, tick and volume normalization, formatting, explicit structure copies | No external resources |
| `PS_Logging.mqh` | `LotCraft`-prefixed diagnostics, duplicate-message throttling, performance-budget instrumentation | In-memory rate-limit slots |
| `PS_Platform.mqh` | Isolated Win32 integration for Unicode clipboard, native F9 New Order request, left-button state, chart-relative pointer recovery, and asynchronous updater launch | Temporary global memory transferred to the clipboard; no persistent hooks |
| `PS_Market.mqh` | Live account, symbol, quote, session, permission, and directional-exposure acquisition | Current `PSMarketSnapshot` only |
| `PS_Risk.mqh` | Model initialization, direction/order-mode transitions, pending subtype inference, protective-price validation, risk authority, one-lot loss, broker-valid volume | `PSCalcResult`; updates the dependent requested-risk view in `PSModel` |
| `PS_Editor.mqh` | Custom numeric-edit state machine | Raw text, cursor, anchor, selection, and pre-edit model snapshot |
| `PS_Persistence.mqh` | Terminal-global persistence for the allowed configuration subset | Keys below `LotCraft.100.<account>.<server-hash>.<chart-hash>` |
| `PS_Exposure.mqh` | Broker-backed projection of current stop-loss outcomes for positions and pending orders | One immutable-per-refresh `PSExposureSnapshot` |
| `PS_UI_Metrics.mqh` | DPI and chart-fit scaling tokens shared by every panel mode and exposure surface | Current scaled geometry only |
| `PS_UI.mqh` | Single-canvas panel, exposure sidecar, chart loss labels, layout, hit testing, line locks, dedicated handles, chart interaction guard, deterministic cleanup | Objects below one instance prefix `LotCraft.v100.<instance-hash>.` |
| `PS_Trade.mqh` | Request construction, `OrderCheck`, `OrderSend`, retcode interpretation, confirmation snapshots, and conservative stop-loss batch execution | Per-action snapshots and temporary request/result records |

## 3. Authoritative state and invariants

`PSModel` is the only domain truth for direction, order mode, configured prices, commission, account basis mode, requested-risk authority, persisted options, and panel state. UI text, chart lines, handles, confirmations, and trade requests are projections from that model plus the latest `PSMarketSnapshot` and `PSCalcResult`.

The controller enforces these invariants:

1. Prices are finite and normalized to `SYMBOL_TRADE_TICK_SIZE` before they become committed model values.
2. Instant Entry is synchronized to Ask for Long and Bid for Short. Pending Entry is the durable manually configured value.
3. An executable Long requires SL below effective Entry and enabled TP above it; Short requires the inverse. A saved planning level remains fixed if the quote crosses it. Such a plan is visible but non-executable until corrected.
4. Final volume follows the broker's volume lattice and capacity limits. Ordinary sizing rounds downward; an explicitly supported below-minimum request uses minimum volume when capacity permits. That exception can exceed requested risk and is identified by `volume_raised_to_minimum` and the separately displayed actual risk.
5. Trade creation and stop modification use separate controller paths and separate request builders.
6. Every chart object that can be deleted by cleanup must prove the current LotCraft instance prefix.
7. LotCraft horizontal lines are repeatedly locked nonselectable and nonselected. Dedicated rectangle-label handles are the only owned chart drag targets.
8. Multi-field symbol and order-mode transitions use a local numeric candidate, then commit once. Rendering never observes a partially changed transition. Execution permission is validated separately.
9. Returning to a saved symbol restores its own Direction/mode/Entry/SL/TP. A first visit uses the current Direction/mode preference and new symbol-scaled prices. Same-symbol timeframe changes restore the saved price plan. Mode changes never translate SL or TP.

## 4. Calculation pipeline

A coherent recalculation follows this sequence:

1. Acquire live account and symbol properties, including Bid/Ask, tick size, digits, contract size, tick values, volume constraints, stops/freeze levels, order/filling/expiration capabilities, account currency, equity, balance, margin mode, and current directional exposure.
2. Resolve the account-money basis from Equity, Balance, or the stored Manual amount.
3. Resolve requested money and percentage from the most recently edited risk authority.
4. Resolve effective Entry and the exact order type. Instant uses the executable side. Pending infers Buy Limit, Buy Stop, Sell Limit, or Sell Stop relative to the current quote.
5. Validate direction, SL, optional TP, order capability, and broker protection distances.
6. Call `OrderCalcProfit()` for one lot from effective Entry to SL. Use the absolute account-currency loss and add the configured commission interpretation.
7. Divide requested money risk by one-lot risk.
8. Cap downward by `SYMBOL_VOLUME_MAX` and remaining directional `SYMBOL_VOLUME_LIMIT`.
9. Quantize downward from `SYMBOL_VOLUME_MIN` in `SYMBOL_VOLUME_STEP` increments. A positive below-minimum request can use the broker minimum, but never exceed maximum or remaining directional capacity.
10. Recompute actual money and percentage risk from final volume. Enforce the risk cap except for the explicit minimum-volume exception.
11. Set `sizing_available` when planning succeeds. Separately set `valid` only when connection, permissions, session, current quote and allowed direction support execution. A usable cached quote can support planning without enabling trade submission.

The calculation layer does not use hard-coded pip values, contract sizes, lot steps, currencies, or instrument-class assumptions.

Commission arithmetic remains in the engine, but the current UI has no commission editor and initialization resets commission to zero. Displayed estimates therefore do not include unknown broker closing fees. Failed directional inventory enumeration invalidates market readiness instead of publishing partial capacity totals.

## 5. Editing state machine

The custom editor has the states `inactive` and `active(field)`. Entry into a field captures:

- raw normalized starting text;
- cursor and selection state;
- a full pre-edit model snapshot.

Each accepted key edits raw text first. A complete valid number is applied immediately to a candidate domain value, so calculations update on the same keystroke while the raw text remains visible. Empty text, a standalone decimal separator, or a standalone sign remains a safe incomplete state and is not applied.

`Enter` validates and normalizes. `Escape` restores the pre-edit model. Click-away commits valid text and rejects invalid text without leaving NaN, infinity, or a partial value in the model. Read-only outputs have no field mapping and cannot enter the editor state.

Input is bounded to 32 characters after subtracting selected replacement text. A measured viewport keeps focused text, caret and selection inside the field; pointer mapping uses that same viewport. Read-only values fit within their bounds or use explicit truncation rather than painting over adjacent controls.

## 6. Pointer ownership and rendering

Hit testing is ordered as follows:

1. Panel bounds and panel controls.
2. LotCraft drag handles outside the panel.
3. Unowned chart space.

Within overlapping level handles, Stop has explicit priority over Entry, and Entry over Take-profit. The canvases use the same z-order and paint order. The captured level is fixed on mouse-down, so later pointer samples cannot transfer a Stop drag to Entry.

Nearby E/S/T markers use separate horizontal lanes while keeping their true price/Y coordinates. Position-loss label lanes exclude the panel, details surface and level handles. Horizontal marker layout changes invalidate the cached label lane; price/Y motion alone does not. If no label lane fits, the details surface remains available.

While LotCraft owns a pointer or keyboard interaction, the UI guard saves and temporarily disables chart mouse scrolling, context menu, crosshair tool, broker trade-level dragging, keyboard chart control, and quick navigation. The exact saved values are restored when ownership ends, on pointer exit, on failure, and during deinitialization.

Mouse capture is explicit in `PSPointerState`. Win32 `GetCursorPos`, `ScreenToClient`, and left-button state provide a timer fallback when the terminal stops emitting chart mouse events after the pointer leaves the panel or chart client area. No Windows hook is installed.

Rendering reuses stable chart objects. Direct manipulation updates only model state, line coordinates, handle coordinates, and dirty UI projections. The full object tree is not recreated on ticks or mouse moves.

## 7. Chart levels

The EA owns exactly three possible levels:

- Entry;
- Stop-loss;
- one optional Take-profit.

Each level has one `OBJ_HLINE` and one separate handle composed of nonselectable label objects. Line visibility and handle visibility are derived independently from global line visibility, level enablement, and the current price viewport. Numeric edits, steppers, and handle movement converge through the model and trigger the same recalculation path.

Line-lock properties are applied at creation, every render that updates a line, chart-object events involving an owned line, drag completion, and a one-second maintenance interval.

## 8. Trade creation state machine

The main action uses this guarded sequence:

1. Reject while another request is in flight or within the duplicate-submit interval.
2. Commit the active editor.
3. Reacquire market/account data and recalculate.
4. Validate permissions, session state when known, symbol direction, order capability, filling, expiration, prices, stops, volume, and risk.
5. Build a complete immutable confirmation snapshot and request.
6. When confirmation is enabled, show requested risk, actual risk, and the send question. Cancellation sends nothing.
7. Rebuild and validate once after confirmation without another new-order confirmation. Invalid refreshed data aborts. A symbol transition cannot reuse the old snapshot.
8. Run `OrderCheck()`.
9. Run `OrderSend()` once.
10. Treat only accepted server retcodes as success and report the actual retcode, order ID, and deal ID when available.

## 9. `Move SLs to line`

Eligibility is every open position and active pending order on the current chart symbol, regardless of the panel's selected direction. A target is included when the red-line SL is valid for that entity and its current SL differs from the red-line price by more than half a tick. This permits both tightening and widening because the button's explicit purpose is exact alignment to the user-positioned line.

Immediately before each request, the implementation reacquires market state, reselects the ticket, rechecks entity type, symbol, direction, current entry, current SL, and broker distance. Position requests use `TRADE_ACTION_SLTP`; pending-order requests use `TRADE_ACTION_MODIFY`. Existing TP and all unrelated order properties are copied from the live entity. Results are reported per ticket, including partial batch failure.

Collection or allocation failure invalidates the complete target set and sends nothing. Unlike the single new-order confirmation, a changed SL-batch target set can require one updated confirmation; a second set change aborts. Pending SL distance is checked from the intended fill using StopsLevel. FreezeLevel separately gates the existing trigger relative to the executable quote. Stop-limit fill and trigger are not interchangeable.

## 10. Persistence and lifecycle

Persisted values are limited to:

- account-money mode;
- stored Manual amount;
- risk authority and requested values;
- commission type and value;
- confirmation state;
- view and theme state;
- line visibility;
- Direction and Instant/Pending preference;
- complete Direction/mode/Entry/SL/TP plans keyed separately by symbol hash.

Global Direction/mode remain defaults for unseen symbols. Each saved symbol overrides them with its complete plan before any default is built. Short per-symbol suffixes fit MT5's key-length limit; a complete-record marker rejects partial writes. The old one-symbol tuple remains a migration/rollback bridge. Invalid executable geometry alone does not discard a finite saved plan. A timeframe change on the same symbol restores the normalized plan. The key includes account login, server hash, and chart ID hash. Object ownership uses account/server/chart-derived instance data.

Terminal-global writes are not a multi-key crash-atomic transaction. MT5 expires globals after four weeks without access; this is not indefinite archival storage. Structural checks govern reload. A failed transition can be canceled by returning to the original symbol without discarding its plan. Hidden waiting or failed-render controls cannot receive actions. Rendering failure retains dirty work and retries at most once per second until the panel is available.

Fresh-symbol planning derives tick-normalized Entry/SL geometry from the quote, price-relative minimum gap and a 34-pixel viewport target when the viewport is coherent. Pending construction prefers a supported Limit between quote and SL and falls back to a supported Stop. If Pending is unsupported, the fresh planning view stays available so the user can choose Instant; execution still rejects the unsupported subtype. Instant-to-Pending preserves SL/TP and creates a buffered pending Entry. Pending-to-Instant replaces only Entry with the executable quote. Both paths recalculate and validate execution afterward.

Deinitialization kills the timer, commits or rolls back any active edit safely, flushes allowed state, restores chart properties, and deletes only objects with the proven instance prefix.

## 11. Installer architecture

The Windows x64 installer is a separate Go program with the canonical `LotCraft.ex5` embedded at build time. It also accepts an explicit payload path for controlled verification. It:

1. Discovers or accepts an MT5 terminal data directory and checks normal terminal-data markers.
2. Resolves the selected path, `MQL5\Experts`, and the dedicated product directory through Windows file handles.
3. Detects reparse components and requires explicit approval while still enforcing final containment inside the resolved Experts root.
4. Hashes canonical, staged, and installed EX5 copies plus the installer.
5. Commits the EX5, copied updater, copied uninstaller, and manifest with sibling backups and rollback.
6. Uninstalls only fixed LotCraft-owned file names after manifest, path, reparse, and hash validation. It never calls recursive directory deletion.

Source files are not installer-owned and are not included in the end-user install set.

The EA offers an updater launch ten seconds after initialization, then hourly while attached, and never in Strategy Tester. It schedules the next opportunity before launch so a failure cannot repeat on every UI timer tick. The installed updater verifies its four-file manifest and hashes, then runs from a verified temporary copy so an approved installer can replace the installed updater. The local install manifest is hash-checked, not signed. An installation-scoped mutex prevents overlapping checks across charts. Network attempts remain throttled for 24 hours, including failures; hourly launches do not bypass the throttle. Older 1.2.0 EAs need a reattachment or restart for a launch opportunity.

Owned-file replacement uses staged files, per-file renames and rollback backups. It is not a crash-atomic four-file commit. Restoration failure must remain an explicit recovery condition, not a successful preservation claim.

The updater accepts only a newer stable semantic version from the latest GitHub release. It verifies an Ed25519 signature over the exact release JSON, then verifies the installer’s signed byte size and SHA-256 before execution. Local per-installation state and a rotating log live under `%LOCALAPPDATA%\LotCraft\Updater`; no account, trading, credential, or telemetry data is collected.

## 12. Performance and observability

Release diagnostics use the prefix `LotCraft`. Repeated technical conditions are rate-limited. Internal budgets are defined for pointer handling, calculation, rendering, and trade validation. Detailed budget logging is disabled in release builds through `PS_DIAGNOSTICS=0`.

## 13. Stop-loss exposure data flow

Exposure refresh is event-driven with a bounded fallback:

```text
OnTradeTransaction / 1 s timer / symbol transition
  -> PS_ExposureCalculate
  -> cached PSExposureSnapshot
  -> main summary + sidecar + chart-label renderers
```

`PS_ExposureCalculate` enumerates open positions and active pending orders, projects each stored Entry-to-SL result through `OrderCalcProfit`, and records missing-SL or unavailable rows explicitly. Open positions include currently accrued swap. Headline totals are downside-only, so a profitable trailing stop never offsets another row's projected loss. Chart scope matches the current symbol exactly; account scope includes every symbol.

For each valid row, loss is `max(0, -projected_result)`; percentages divide that loss by current positive finite equity. Pending stop-limit orders use the limit leg as the projected fill. No magic-number filter is applied. Failed selection, array allocation or inventory count drift invalidates the snapshot and triggers a bounded retry. Missing-SL and unavailable rows retain their counts; a summary with such rows says Incomplete and labels the known protected amount. Invalid enumeration says Unavailable. Zero equity removes the percentage, not valid money results. Count checks cannot prove a transactionally frozen inventory when tickets change without a count change.

The panel summary, details sidecar, and chart labels consume the same cached snapshot. Rendering never re-enumerates broker positions or orders. Pointer movement stays on the existing line-only path; exposure calculation and label collision resolution run only on trade/symbol/timer refresh or an explicitly dirty render surface.

The sidecar is one bitmap canvas with adaptive right, left, below, above, then clamped-overlay placement. Its page capacity is derived from available height, up to eight rows. Price/volume precision is cached per symbol before paint. Open-position chart labels use up to 128 individual opaque bitmap canvases, bounded by available vertical space, not one combined canvas; pending orders remain in details. Hit precedence outside the panel is handles, sidecar, exposure labels, then unowned chart space.
