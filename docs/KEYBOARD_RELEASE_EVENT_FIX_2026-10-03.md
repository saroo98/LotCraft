# Release-only keyboard shortcut correction

## Scope and authority

On 2026-10-03, the owner authorized implementation and installation of a corrected local test build in both MT5 terminals after completing the observation-only diagnostic. No commit, push, signing, publication, desktop control, terminal restart, live trade or security-setting change is included.

## Current local status

The missing-key-press correction is accepted by the owner's report for copy, paste, cut and undo. The remaining Ctrl+A failure was traced to a blanket shortcut-context reset during a chart-layout event. That reset is removed, and clean, non-instrumented local builds are installed in both terminals. Owner-run Ctrl+A acceptance remains pending. Public release 1.2.3 is unchanged and remains affected.

## Initial confirmed cause

The build-6230 traces from both terminals contain Ctrl presses and A/C/V/X/Z releases, but no corresponding shortcut-letter presses. All recorded letter releases have an active editor, ready panel and no symbol transition. At the start of this correction, the key-up handler only updated modifiers. Independent replay of 42 IC Markets events and 32 Darwinex events through those production handlers produced zero editor-command or clipboard calls.

Most recorded shortcut-letter releases occur after Ctrl release. The correction must retain that gesture's modifier context. The internal MT5/Windows reason for missing press delivery was not observed and is not claimed.

## Sequential implementation plan

- [x] Inspect current controller, reset paths and build/deploy boundaries; preserve the pre-existing dirty work.
- [x] Add behavioral regression cases for release-only shortcuts, both modifier release orders, delivered-press deduplication, all numeric fields and blocked editors. The ten A/C/V/X/Z cases failed on the original production handlers for the expected missing-command behavior.
- [x] Reuse the current editor action path from press and release handling. Track the finite shortcut-key press set and gesture modifier/field context. Clear context on normal key presses, explicit mouse/focus changes, actual symbol transitions and lifecycle reset. Preserve context across layout-only events. Keep ordinary editing and trading semantics unchanged. All 34 release-delivery behavioral cases passed after the initial correction.
- [x] Run targeted native-body tests, the complete documented test suite and both MetaEditor compilers. Review the diff against the preserved prechange files. State all skips and limitations.
- [x] Back up both installed four-file inventories. Install the verified copied-source candidates quietly through the existing explicit-payload installer. Verify payloads, manifests, helpers and unchanged terminal processes. Request native acceptance before publication.

## Acceptance

Ctrl+A/C/V/X/Z must work with press-and-release delivery and release-only delivery. Releasing Ctrl first must not discard the command. Copy/paste/undo must not execute twice. All numeric editor fields use the same handler. Plain typing, Backspace/Delete, caret movement, selection, alternate clipboard shortcuts and undo/redo keep their existing behavior. Blocked panels, stale fields and reset contexts must not execute pending commands.

Runtime acceptance remains an owner-run test in each terminal. Offline production-body fixtures do not prove the native clipboard/DLL boundary or final UI behavior.

## Verification record

Red: the ten release-only A/C/V/X/Z cases failed for the expected missing-command assertions before implementation. Green: all 34 cases in `tests/test_native_shortcut_release.py` passed after implementation. The 107 existing targeted clipboard/controller/render tests passed. The full documented Python suite completed with 552 passed and two private-station clipboard integration skips (Windows error 5). All four Go test packages passed. Both MetaEditor compilers reported zero errors and zero warnings.

The shared editor-action body is byte-for-byte the previous action body after substituting explicit modifier arguments. Pre-existing platform changes are unchanged. Copied include files match canonical sources, and probe-stripped controller/lifecycle bodies match the corrected canonical bodies. The default Git whitespace check passed. Separate checkout changes were preserved.

Both quiet explicit-payload installers exited 0. Independent postinstallation verification confirmed each exact four-file inventory, schema-2 ownership paths, candidate/staged/installed EX5 hashes, helper hashes, retained rollback backups and unchanged terminal process identities. Public setup and public EX5 bytes are unchanged. No commit, push or publication occurred.

The installed local test copies retain the 1.2.3 label and identify themselves in a value-free trace as `LC-KF-20261003-B`. The trace expires after three minutes per initialization or 32 approved command/modifier events. Canonical production source contains no probe. Full native acceptance remains pending.

## Partial native result and remaining investigation

The owner reports that the shortcuts now work except Ctrl+A and Ctrl+Z. The IC Markets trace confirms that release-only cut and paste reach the shared editor-command path, including paste after Ctrl release. This supports the event-dispatch correction but does not prove every clipboard transfer or selection/history behavior.

That capture reached its 32-event limit during repeated Ctrl presses. It contains no Ctrl+A or Ctrl+Z command records. No correction-build trace was present in the inspected Darwinex log. Absence of a trace is not evidence of failure or activation in that terminal. The existing automated A/Z cases pass, but they cannot explain the owner's remaining native failures.

No further controller or editor change is justified by this incomplete capture. The next test must distinguish missing command delivery or lost gesture context from selection rendering and undo-history state. History is scoped to the active editor session; focus changes or committing the field end that session.

- [x] Inspect the partial native capture and current select-all/undo paths.
- [x] Capture Ctrl+A and Ctrl+Z first in a fresh IC Markets initialization, with brief key presses and no intervening focus change or commit. The owner reports that Ctrl+Z works but Ctrl+A does not.
- [x] Reproduce the evidence-confirmed failure at the appropriate seam and implement the smallest correction. See the layout-event evidence below.
- [ ] Verify affected behavior and obtain native acceptance before any publication.

Owner test: reattach once, single-click SL, briefly press and release Ctrl+A, then press Right Arrow and Backspace. Briefly press and release Ctrl+Z without clicking away or pressing Enter. Press Escape to cancel the test edit. Report whether Ctrl+A selected all text and Ctrl+Z restored the removed character. Do not place a trade. The probe records no field values.

### Select-all context loss: focused native evidence

The subsequent IC Markets capture contains 13 approved key events. The first Ctrl press has flags 29 and establishes a logical pressed state. Before Ctrl release, the saved shortcut context and saved editor identity have already been cleared. The later A release arrives with an active editor, ready panel and no symbol transition, but with no saved Ctrl context. It therefore does not reach the editor command. Later Z releases retain the saved context and reach the undo action. The owner confirms that undo now works. These observations locate the remaining failure in context retention, not in the select-all primitive; the precise invalidation caller is not recorded in that capture.

Ranked hypotheses: a chart-layout event clears the context; an explicit mouse/focus event clears it; or another delivered key replaces the gesture. [MT5's official shortcut contract](https://www.metatrader5.com/en/terminal/help/start_advanced/hotkeys) assigns Ctrl+A to indicator-window height adjustment. A resulting chart-change reset is a leading hypothesis, not yet an observed native fact.

An observation-only copy tagged `LC-KA-20261003-C` was installed into IC Markets only. It records a finite invalidation reason and boolean context state before resets or context replacement. It keeps the three-minute/32-event bounds and suppresses repeated modifier records. It does not log field values, ordinary typed text, clipboard contents, positions, account data or mouse coordinates. Canonical application code and every canonical include remain unchanged by this probe.

Fresh verification: the probe-stripped complete EA equals canonical source; copied includes are byte-identical; all 34 release-delivery regression cases pass; the hidden IC Markets compiler reports zero errors and warnings. The existing setup signature, size and hash verify. All four installed files were backed up with matching hashes. The successful quiet installer exited zero, and independent verification confirms the installed candidate and schema-2 ownership/hashes. Both terminal processes are unchanged and all Darwinex installed files are unchanged. No terminal restart, desktop input, security change, commit, push or publication occurred.

A preliminary installation invocation had malformed PowerShell argument concatenation and stopped before installation. Only that task-owned helper was stopped. Fresh verification proved that both installations and terminal processes were unchanged before the corrected five-argument quiet invocation. Do not represent the preliminary invocation as a successful installation.

At this diagnostic stage, the owner was asked to reattach once in IC Markets, single-click SL and briefly press/release Ctrl+A within three minutes. The resulting trace identified the reset caller, as recorded below. This earlier instrumented installation is no longer the installed candidate.

Local evidence: [source/probe boundary verifier](../build/keyboard-a-context-20261003-1791029718199/verify_observation_only.py), [34-case results](../build/keyboard-a-context-20261003-1791029718199/unchanged-controller-tests.xml), [compiler log](../build/keyboard-a-context-20261003-1791029718199/ic-markets/LotCraft-compile.log), and [private installation verification](../build/keyboard-a-context-20261003-1791029718199/installation-verification.json). These are ignored local artifacts, not publication-ready assets.

### Confirmed layout-event cause and local correction

The reset trace records this sequence: Ctrl press establishes a saved gesture for the active editor; a chart-change invalidation clears that gesture while the same editor remains active; Ctrl release follows; A release then arrives without Ctrl context and produces no selection. This directly identifies the blanket reset in the `CHARTEVENT_CHART_CHANGE` branch of `OnChartEvent`. The MT5 hotkey documentation explains why a layout event is plausible, but the captured reset sequence, not that inference, establishes the application-side defect.

The smallest functional change removes that one reset. Layout events still refresh the market and clamp and repaint the panel. A true symbol change still invokes the existing `PS_AbortInteractionForContextChange` path, which resets the editor and keyboard state. Explicit mouse/focus changes and shutdown still invalidate pending commands.

The new `tests/test_native_shortcut_layout.py` executes the production callback, keyboard/editor functions and context-abort function with offline platform, market-refresh and rendering boundaries. Before the code change, three captured-path cases failed at the expected missing-selection assertions. After the change, all eight new cases and the 34 release-delivery cases passed. Coverage includes both modifier-release orders, a layout after Ctrl release, delivered-paste deduplication, true context changes and explicit pointer invalidation. It does not emulate native MT5 or exercise the real clipboard.

Fresh completion gates: 560 Python tests passed; two private-station clipboard integration cases skipped because Windows denied station creation with error 5. All four Go packages passed normal and race tests; vet exited zero. Both MetaEditor logs report zero errors and zero warnings and produced fresh candidates. The compiler process exit value was 1 despite the clean summaries; it is not reported as exit-zero compiler evidence. The entire canonical EA matches the preserved prechange file except the single reset removal and explanatory comment. Platform source is unchanged, and all 12 copied source files match the canonical source hashes. No diagnostic probe is included in the compiled candidates.

Both preinstallation four-file inventories were backed up and hash-verified before either install. Both quiet explicit-payload installers exited zero. Independent postinstallation checks verify exact owned-file inventories, schema-2 paths, candidate/staged/installed hashes, helper hashes and unchanged terminal process identities. Public setup and canonical release EX5 remain unchanged. These local, non-instrumented candidates retain the 1.2.3 label. No terminal restart, desktop input, live trade, security change, commit, push or publication occurred.

Owner acceptance: reattach LotCraft once in each terminal, single-click a numeric field and press Ctrl+A. Confirm that the entire value is selected. Do not place a trade. Native acceptance of this final correction is still pending; offline passing tests and disk installation do not prove it.

Latest local evidence: [expected layout failures](../build/keyboard-a-fix-20261003-1791031050984/layout-red.xml), [42 focused cases](../build/keyboard-a-fix-20261003-1791031050984/keyboard-green.xml), [full Python results](../build/keyboard-a-fix-20261003-1791031050984/full-suite.xml), [IC Markets compiler log](../build/keyboard-a-fix-20261003-1791031050984/ic-markets/LotCraft-compile.log), [Darwinex compiler log](../build/keyboard-a-fix-20261003-1791031050984/darwinex/LotCraft-compile.log), and [private installation verification](../build/keyboard-a-fix-20261003-1791031050984/installation-verification.json). These artifacts are ignored and require privacy review before any publication.

## Local evidence

- [Expected pre-fix failures](../build/keyboard-release-fix-20261003-1791018956581/release-red-all.xml)
- [New regression results](../build/keyboard-release-fix-20261003-1791018956581/release-green.xml)
- [Existing targeted results](../build/keyboard-release-fix-20261003-1791018956581/existing-targeted.xml)
- [Full Python results](../build/keyboard-release-fix-20261003-1791018956581/full-suite.xml)
- [IC Markets compiler log](../build/keyboard-release-fix-20261003-1791018956581/ic-markets/LotCraft-compile.log)
- [Darwinex compiler log](../build/keyboard-release-fix-20261003-1791018956581/darwinex/LotCraft-compile.log)
- [Installation verification](../build/keyboard-release-fix-20261003-1791018956581/installation-verification.json)

These outputs are local and ignored. Do not publish them without a separate privacy review.

Build and installation evidence stays in ignored build output. No numeric, clipboard or account contents from the owner's session are included in tracked test fixtures or this document.
