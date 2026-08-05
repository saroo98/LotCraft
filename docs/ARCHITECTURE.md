# LotCraft 1.1.0 Architecture

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
| `PS_UI.mqh` | Custom chart-object rendering, layout, hit testing, line locks, dedicated handles, chart interaction guard, deterministic cleanup | Objects below one instance prefix `LotCraft.v100.<instance-hash>.` |
| `PS_Trade.mqh` | Request construction, `OrderCheck`, `OrderSend`, retcode interpretation, confirmation snapshots, and conservative stop-loss batch execution | Per-action snapshots and temporary request/result records |

## 3. Authoritative state and invariants

`PSModel` is the only domain truth for direction, order mode, configured prices, commission, account basis mode, requested-risk authority, persisted options, and panel state. UI text, chart lines, handles, confirmations, and trade requests are projections from that model plus the latest `PSMarketSnapshot` and `PSCalcResult`.

The controller enforces these invariants:

1. Prices are finite and normalized to `SYMBOL_TRADE_TICK_SIZE` before they become committed model values.
2. Instant Entry is synchronized to Ask for Long and Bid for Short. Pending Entry is the durable manually configured value.
3. Long SL is below effective Entry and enabled TP is above it. Short SL is above effective Entry and enabled TP is below it.
4. A nonzero final lot size is aligned downward to the broker volume lattice and is rechecked so volume rounding cannot make actual risk exceed requested risk.
5. Trade creation and stop modification use separate controller paths and separate request builders.
6. Every chart object that can be deleted by cleanup must prove the current LotCraft instance prefix.
7. LotCraft horizontal lines are repeatedly locked nonselectable and nonselected. Dedicated rectangle-label handles are the only owned chart drag targets.
8. Multi-field symbol and order-mode transitions are constructed and validated in a local candidate model, then committed once. Rendering never observes a partially changed transition.
9. Different-symbol transitions preserve Direction and Instant/Pending preference but generate new symbol-scaled prices. Same-symbol lifecycle changes restore the complete saved price plan.

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
9. Quantize downward from `SYMBOL_VOLUME_MIN` in `SYMBOL_VOLUME_STEP` increments. Reject a result below minimum.
10. Recompute actual money and percentage risk from the final volume and verify the no-risk-overrun postcondition.

The calculation layer does not use hard-coded pip values, contract sizes, lot steps, currencies, or instrument-class assumptions.

## 5. Editing state machine

The custom editor has the states `inactive` and `active(field)`. Entry into a field captures:

- raw normalized starting text;
- cursor and selection state;
- a full pre-edit model snapshot.

Each accepted key edits raw text first. A complete valid number is applied immediately to a candidate domain value, so calculations update on the same keystroke while the raw text remains visible. Empty text, a standalone decimal separator, or a standalone sign remains a safe incomplete state and is not applied.

`Enter` validates and normalizes. `Escape` restores the pre-edit model. Click-away commits valid text and rejects invalid text without leaving NaN, infinity, or a partial value in the model. Read-only outputs have no field mapping and cannot enter the editor state.

## 6. Pointer ownership and rendering

Hit testing is ordered as follows:

1. Panel bounds and panel controls.
2. LotCraft drag handles outside the panel.
3. Unowned chart space.

Within overlapping level handles, Stop has explicit priority over Entry, and Entry over Take-profit. The canvases use the same z-order and paint order. The captured level is fixed on mouse-down, so later pointer samples cannot transfer a Stop drag to Entry.

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
6. When confirmation is enabled, display every required field. Cancellation sends nothing.
7. Rebuild after confirmation. A material change causes one updated confirmation. A second material change aborts without sending.
8. Run `OrderCheck()`.
9. Run `OrderSend()` once.
10. Treat only accepted server retcodes as success and report the actual retcode, order ID, and deal ID when available.

## 9. `Move SLs to line`

Eligibility is every open position and active pending order on the current chart symbol, regardless of the panel's selected direction. A target is included when the red-line SL is valid for that entity and its current SL differs from the red-line price by more than half a tick. This permits both tightening and widening because the button's explicit purpose is exact alignment to the user-positioned line.

Immediately before each request, the implementation reacquires market state, reselects the ticket, rechecks entity type, symbol, direction, current entry, current SL, and broker distance. Position requests use `TRADE_ACTION_SLTP`; pending-order requests use `TRADE_ACTION_MODIFY`. Existing TP and all unrelated order properties are copied from the live entity. Results are reported per ticket, including partial batch failure.

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
- one complete Entry/SL/TP planning snapshot guarded by the saved symbol hash.

Direction and order mode load independently of the symbol hash. Entry, SL, and TP load only as one complete set when the saved symbol matches the current symbol and the plan is structurally coherent. A different symbol therefore keeps the user's planning preferences but never reuses old-symbol numbers. A timeframe change on the same symbol restores the exact normalized plan. The key includes account login, server hash, and chart ID hash. Object ownership includes account/server/chart-derived instance data.

Fresh-symbol planning derives a broker-valid, tick-normalized Entry/SL geometry from the new quote, symbol capabilities, price-relative minimum gap, and a 34-pixel viewport target when the viewport is coherent. Pending construction prefers a supported Limit between quote and SL and falls back to a supported Stop. Instant-to-Pending uses the same candidate discipline, preserves SL exactly, and creates an unambiguous buffered pending Entry before recalculation.

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

The EA launches the updater once, ten seconds after initialization, and never in Strategy Tester. The installed updater first verifies its four-file schema and hash, then runs the check from a verified temporary copy so an approved installer can replace the installed updater atomically. An installation-scoped Windows mutex prevents overlapping checks across charts.

The updater accepts only a newer stable semantic version from the latest GitHub release. It verifies an Ed25519 signature over the exact release JSON, then verifies the installer’s signed byte size and SHA-256 before execution. Local per-installation state and a rotating log live under `%LOCALAPPDATA%\LotCraft\Updater`; no account, trading, credential, or telemetry data is collected.

## 12. Performance and observability

Release diagnostics use the prefix `LotCraft`. Repeated technical conditions are rate-limited. Internal budgets are defined for pointer handling, calculation, rendering, and trade validation. Detailed budget logging is disabled in release builds through `PS_DIAGNOSTICS=0`.
