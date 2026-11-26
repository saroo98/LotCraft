# LotCraft 2.0.0 release report

Date: 2026-11-26

This report separates what was verified from what was not. Offline checks are not native MT5 or broker certification.

## Changes

Order safety:

- Enter or Space can no longer re-send a clicked Trade or stop-loss batch. Only Tab gives an action control keyboard focus, and a keyboard send spends that focus.
- Key auto-repeat never activates a control. A confirmation opened from the keyboard defaults to No.
- The duplicate-submit interval is stamped again when the blocking send returns.
- Requests carry no order comment. The magic number stays 0.
- A requested new order that is not placed is logged and shown in a dialog, because the panel paints no status line.
- Release detection follows the logical primary mouse button (swapped buttons).
- A press where the exposure details overlap the panel activates nothing, and never captures a level handle inside the details.
- A panel canvas deleted by another program is recreated on the next paint.

New controls:

- `SL to line` (previously `Move SLs to line`) and `TP to line`. The take-profit batch never changes a stop-loss, entry or volume, lists every ticket before sending, and aborts if the eligible set changes during confirmation.
- `Fill order window` types volume, SL, TP and pending price into MT5's own New Order window, then reads the boxes back. It never presses Buy or Sell. The window's send-button identifiers are not present in the source, and a static test enforces that.

Display:

- Pips beside the S and T markers and inside the SL and TP fields. The TP field also shows broker-calculated profit for the planned size.
- Pip size is chosen by instrument class: forex by quote precision, gold 0.10, silver 0.01, indices and crypto 1.00, shares 0.01. Only the forex definition is a market standard; the others follow common convention and can differ from a given broker's own.
- Marker letters are centred on their inked pixels.

Behaviour and performance:

- Markers and labels follow a price-scale change on the timer frame.
- Panel drag makes no blocking chart query per frame and also moves on mouse events between timer ticks.
- Panel position survives re-initialization. An uncommitted edit is discarded before a symbol's plan is saved. Risk % shows up to four decimals.

## Verified

| Check | Result |
|---|---|
| MetaEditor compile of the release source | Recorded by the release build: zero errors and zero warnings required |
| Go installer packages: build, vet, test | Pass |
| Python static contract and reference-model tests | Pass, see boundary below |
| Owner use in live terminals | Fill, pips labels, TP profit note and panel drag reported working |

## Not verified

- The native C++ fixture tests (322 cases, including the new keyboard and duplicate-guard cases) did not run for this release: no `g++` was available on the build machine. They are updated in source but unexecuted.
- The Python cases were run with a minimal stand-in runner because `pytest` was not installed on the build machine. Installer binary and release-verifier test modules were not run that way.
- `TP to line` was not exercised against live positions by the author of the change.
- `Fill order window` relies on control identifiers read from one MT5 build. Another build or broker terminal can differ; the feature then reports a failure instead of filling.
- No Strategy Tester or broker acceptance run was performed.

## Known limitations carried forward

See [known limitations](KNOWN_LIMITATIONS.md). In addition:

- The panel still paints no status line. Order failures use a dialog; other notices, including the minimum-lot notice, are not shown on the panel.
- There is no upper bound on Risk %.
- The order sent after confirmation is rebuilt from fresh quotes and is not compared with the confirmed one.
- Orders sent by the EA are recorded by MT5 as placed by an Expert. Orders the user sends from MT5's own window after `Fill order window` are the user's own.
