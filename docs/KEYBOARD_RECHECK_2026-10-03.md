# Keyboard failure after 1.2.3: audit and implementation plan

This document records the initial offline recheck and local test installation. The later value-free native diagnostic established release-only delivery and the Ctrl+A layout reset. See the [subsequent investigation](KEYBOARD_RELEASE_EVENT_FIX_2026-10-03.md) and [1.2.4 release evidence](RELEASE_1.2.4.md) for the final correction and remaining acceptance boundary. Do not treat the initial hypotheses below as current native observations.

## Scope

The owner reports that C buttons work, but Ctrl+A, selected-text Ctrl+C and Ctrl+V still fail. Diagnose the current event-to-editor path. Preserve numeric validation, trading behavior, themes, layouts and working C buttons. Do not treat prior function tests or publication as proof of native keyboard behavior.

Use background checks only. Do not control desktop input, read the user's clipboard, launch or restart terminals, submit trades, change security settings or use MQL/MT5 skills. Keep private logs and terminal identities outside tracked evidence. Preserve the separate dirty checkout. This recheck starts with a clean feature checkout at `0c81bbe`.

## Live plan

1. Completed: inspect current source, tests, build workflow and installed version. Both installed manifests and EX5 hashes match 1.2.3. Filtered IC Markets startup logs prove that 1.2.3 was loaded. A stale installed build does not explain this report.
2. Completed for the offline boundary: three production-controller regressions fail at the expected assertions with independently supplied Windows and terminal states. Held Windows Ctrl/Shift plus a zero terminal observation loses shortcuts/selection; a stale terminal pressed state can also suppress ordinary input after Windows release. The high-bit mask is correct by documentation. The owner's exact native observations and plain-key result remain unavailable; these cases establish a concrete vulnerable path, not proof of the affected terminal's internal state.
3. Completed for the offline boundary: the initial Windows-polling change was insufficient. Six delayed/future-event regressions failed before correction, then passed. Delivered modifier events now own both pressed and released states. Physical observation seeds unknown state only. Mouse snapshots rebase state. Two left/right overlap regressions and two mouse/overlap intersections failed before correction, then passed. Generic MT5 events use their scan/extended flags to identify the side. Two unnecessary keyboard-render cases also failed before correction, then passed: modifier events now avoid painting, and ordinary editor updates use the existing frame timer. Focus polling was implemented provisionally, then removed after review proved that call-time focus can also erase an older queued shortcut. No polling-based native focus-recovery claim remains. No numeric editing, clipboard API redesign, input hooks or window activation is included.
4. Completed: final read-only review reports no remaining Critical or Important finding in the delivered-event path. The final Python suite passes 518 tests and safely skips two isolation fixtures. Both hidden MetaEditor builds report zero errors/warnings; all 12 copied sources match. The diff/privacy check passes and unrelated work and installed binaries are unchanged. Preliminary results belong to rejected earlier revisions, not final evidence.
5. Completed for the reviewable handoff: source correction, final builds, findings and exact verification limits are recorded. A test-only installation was offered separately; approval and native acceptance were pending at that handoff. The owner subsequently authorized the test installation recorded below. The affected native terminals are not labeled fixed and no published signed installer was replaced.

## Authorized test installation: live plan

The owner authorized background installation into IC Markets and Darwinex on 2026-10-03. Use the existing verified 1.2.3 setup in documented explicit-payload mode with each terminal's copied-source test binary. Keep public release assets unchanged. This local test still displays version 1.2.3; distinguish it by its EX5 hash, not by the displayed version.

1. Completed after owner restoration: both candidate hashes and all 12 source copies still match the final builds; both compiler logs record zero errors/warnings. The existing JUnit artifact records 520 cases, zero failures/errors and two skips. These are checked prior-run artifacts, not newly executed tests. After the owner restored the setup, its SHA-256 and size match the release descriptor and the pinned-key release signature verifies. Both exact terminal origin mappings, normal paths, manifest identities and hashes of all present owned files pass the target preflight. Both terminals are currently running.
2. Completed: all three present IC Markets owned files and all four Darwinex owned files were backed up with matching hashes before either installation. Both quiet installer invocations returned exit code zero. The previously absent IC Markets updater is included in the installer repair. The owner restored and allowed the detected executable; the agent did not change security settings or substitute another executable.
3. Completed: both installations contain exactly the four owned files. Installed EX5 hashes match their respective test candidates. All schema, product, version, ownership paths, canonical/staged/installed EX5 hashes and helper hashes verify. Both terminal process IDs and creation times are unchanged across installation. Released setup and released EX5 bytes are unchanged. This confirms installation, not activation of an already-attached EA.
4. Completed for the installation handoff: verification and backups are retained in an ignored local evidence directory. The whitespace check and narrow private-pattern check pass; separate unrelated checkout changes remain unchanged. Report reattachment and native testing to the owner. No commit, push, publication, terminal restart or native keyboard acceptance claim is made.

### Installation blocker evidence

On 2026-10-03, `Get-FileHash` rejected `LotCraft-1.2.3-Setup.exe` with a virus-or-potentially-unwanted-software error. A read-only Windows Defender query associates that exact setup with `Trojan:Win32/Bearfoos.B!ml`, threat ID `2147731849`. The detection name is not evidence that this is a false positive. Do not assert that the blocked binary is safe while its current bytes cannot be verified.

At the initial blocked attempt, no installer was executed, no backup or replacement was started, no terminal was launched or restarted, and no security setting was changed. The owner subsequently reported restoring the exact setup. Its recorded release identity and signature now verify. This establishes artifact identity, not a malware false-positive verdict. The currently absent IC Markets updater is recorded separately; do not attribute its absence to a specific cause without evidence.

### Installed test-build evidence

Both explicit-payload quiet installs completed on 2026-10-03 with exit code zero. Independent verification confirms:

- IC Markets now contains the 281,032-byte test EX5 with SHA-256 `8e560d7561b6fb2548b62b5171c63344b2311c5809ccf1cf30c8567fbc41cb91`.
- Darwinex now contains the 281,204-byte test EX5 with SHA-256 `fd7bdbd9bb7d13b9796b33a8a2f21625dafa67b069960f01a16cdc702c0a4188`.
- Both complete schema-2 manifests, four-file inventories and updater/uninstaller hashes verify. IC Markets' previously absent updater is restored.
- Both original terminal processes remain running with unchanged process IDs and creation times. No activation of the test build was performed or observed.
- All files present before installation have hash-verified backups. IC Markets' missing pre-install updater was recorded rather than represented as an existing backup.
- The public release setup and EX5 remain unchanged. This local test installation is not a published update.

Private local [installation verification](../build/keyboard-test-install-20261003-1791015784068/installation-verification.json) and backups remain ignored. Reattach LotCraft on the chart to load the test code before native keyboard testing. The version label remains 1.2.3.

## Evidence and findings

| Finding | Impact | Confirmed evidence | Uncertainty / acceptance |
|---|---|---|---|
| Modifier fixture is coupled to controller state | High verification gap: shortcuts can pass tests while native modifiers fail | `tests/test_native_clipboard.py` defaults `TerminalInfoInteger` to values derived from `g_ctrl_down/g_shift_down`, the flags under test. The explicit native cases hard-code high-bit values | Decouple observed key state from logical event state. Execute real controller/editor bodies and assert clipboard, selection and raw-text results |
| Modifier down events are overwritten by later polling | Potential high usability defect | `PS_HandleKeyDown` sets flags for Ctrl/Shift events but replaces them on every next key with a new terminal observation. A zero observation therefore discards a delivered modifier press | Reproduce a contradictory or delayed observation independently. Determine the smallest safe correction, including release/focus recovery. The native observation on the affected terminal is not yet captured |
| Disabling chart keyboard scrolling does not disable key events by contract | Eliminates a tempting speculative fix | MetaQuotes explicitly states that `CHART_KEYBOARD_CONTROL=false` preserves `OnChartEvent` key-press events | Retain the interaction guard unless separate evidence contradicts this behavior |
| Shortcut handling depends on chart input focus | Possible event-delivery cause | MetaQuotes documents key events only for a focused chart. LotCraft's visual editor is drawn on a canvas, not a native Windows edit control | Distinguish missing key events from incorrect modifier interpretation; do not assume visual selection establishes native focus |
| Call-time physical polling can erase or invent modifiers | High: fast Ctrl+A/C/V and Shift selection can fail; a plain key can run a shortcut | Six production-controller tests fail with delivered Ctrl/Shift events processed after physical release, or a later physical press before an older plain key. These are deterministic event-order defects | Fixed offline by preserving known true AND known false delivered-event states. All six regression cases pass. Real MT5 queue delivery is still unproven |
| Releasing one modifier side clears another held side | Medium: overlapping left/right Ctrl or Shift loses copy or selection | Two delivered-side overlap traces fail before the side-state correction | Corrected using independent delivered-side bits and the actual MT5 scan/extended mask. Direct and generic-key overlap cases pass |
| Held mouse snapshots discard delivered side identity | Medium: mouse movement followed by one side's release loses another held Ctrl/Shift | Two intersection traces fail before correction | A held snapshot adds an aggregate seed without discarding delivered side bits; a released snapshot clears all bits. Both regressions pass |
| Modifier and ordinary key events synchronously repaint the panel | Medium reliability/performance risk: unnecessary rasterization lengthens chart-event handling | Two production-controller regressions observe painting for modifier-only events and ordinary field edits | Modifier events return without editor mutation or painting. Numeric changes and clipboard feedback still mark UI dirty; the existing timer paints it. Native event-loss reduction is not measured |
| A release outside the chart has no chart KEYUP | Native delivery limitation: a keyboard-only return can retain an unobserved modifier | Mouse snapshots provide an event-ordered rebase. Current-time focus polling cannot determine the focus at which an older queued key was generated | Keyboard-only focus recovery without delivered release or mouse snapshot is not certified. Focus polling was rejected, not relabeled as a fix. Native event observation is needed before changing this contract |

## Primary references

- [MT5 terminal key-state contract](https://www.mql5.com/en/docs/constants/environment_state/terminalstatus): GetKeyState-compatible values. The high-bit mask is documented, so changing it to a guessed mask is not justified.
- [MT5 keyboard event contract](https://www.mql5.com/en/book/applications/events/events_keyboard): chart input focus is required; keyboard `sparam` contains scan/transition flags, not the mouse Ctrl/Shift mask.
- [MT5 chart keyboard control](https://www.mql5.com/en/docs/constants/chartconstants/enum_chart_property): disabling built-in chart scrolling preserves key-press events.
- [Windows GetKeyState](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getkeystate): message-queue state differs from physical keyboard state.
- [Windows GetAsyncKeyState](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getasynckeystate): only the high bit reliably represents current pressed state. The existing EA already imports this function for pointer-release recovery.
- [Windows GetGUIThreadInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getguithreadinfo): current foreground information cannot establish the focus when an older chart event was generated. Do not reset delivered state from this observation.
- [Windows MapVirtualKeyW](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-mapvirtualkeyw): map the right Shift virtual key to its scan code without observing which key is currently pressed. MT5's keyboard scan/extended flags occupy bits 0..7/8, not the unshifted Windows lParam positions 16..23/24.
- [MT5 event queue](https://www.mql5.com/en/docs/runtime/running): delivered events are processed in received order; chart events may not be enqueued while another chart event is queued or being processed. Function fixtures do not prove that every native event is delivered.

## Acceptance boundary

Offline production-function tests can establish controller/editor behavior for stated native inputs. Hidden compilation can establish MQL syntax and imports. Neither proves real MT5 shortcut delivery or clipboard marshalling. Do not generate desktop input or introduce global keyboard hooks to hide this boundary. If native observation remains necessary, report the exact missing check and use a bounded, value-free diagnostic only with the owner's knowledge.

## Final verification evidence

| Check | Observed result | Boundary |
|---|---|---|
| Review | No remaining Critical or Important finding in the delivered-event path | Read-only source review; not native MT5 acceptance |
| Full Python suite | 518 passed, two skipped, zero failures/errors in 135.92 seconds | Both skipped Windows clipboard fixtures refuse private-station creation with Windows error 5. No interactive fallback |
| Clipboard/editor regressions | Independent Windows/terminal states, delayed Ctrl+A/C/V, delayed Shift selection, known releases, left/right overlap, mouse overlap, copy/paste validation, cut/undo/redo, numeric keypad, Tab order, commit/cancel and redraw deferral are exercised | Executed production function bodies with explicit native API stubs. Real chart event delivery, TranslateKey locale behavior and MQL DLL marshalling remain unverified |
| IC Markets compiler | Zero errors/warnings; 281,032-byte EX5; all 12 source copies match | Hidden copied-source compilation only |
| Darwinex compiler | Zero errors/warnings; 281,204-byte EX5; all 12 source copies match | Same boundary. Compiler outputs need not be byte-identical |
| Native Shift mapping | Read-only User32 MapVirtualKeyW returns left/right scan codes 42/54 | No keyboard input, focus change or clipboard access. This is not a native MT5 shortcut test |
| Diff/privacy/preservation | Default Git whitespace check and narrow private-pattern scan pass. Separate dirty checkout remains unchanged. Both installed EX5 hashes remain the 1.2.3 baseline | No commit, push, publication, signing-key change or production installation occurred in this recheck |

Final copied-source binary SHA-256 identities:

- IC Markets: `8e560d7561b6fb2548b62b5171c63344b2311c5809ccf1cf30c8567fbc41cb91`
- Darwinex: `fd7bdbd9bb7d13b9796b33a8a2f21625dafa67b069960f01a16cdc702c0a4188`

Private local evidence remains ignored and is not a release asset:

- [Final Python JUnit](../build/keyboard-recheck-20261003/pytest-event-final.xml)
- [IC Markets final compiler log](../build/keyboard-recheck-20261003/ic-markets-final/LotCraft-compile.log)
- [Darwinex final compiler log](../build/keyboard-recheck-20261003/darwinex-final/LotCraft-compile.log)

## Required native check before another completion claim

The owner or a configured isolated MT5 environment must reattach LotCraft and test the newly installed test binary, not an already-loaded release binary. The local test still displays 1.2.3; the installed EX5 hashes above distinguish it. Do not submit a trade. In SL, risk percentage and Manual account fields, check digits/Backspace first, then Ctrl+A, selected-text Ctrl+C and Ctrl+V. Check both full and partial mouse selection, left/right Ctrl, Shift arrows, cut, undo/redo, Tab/Shift+Tab and Enter/Escape. Test a normal field click after returning from another application. Record keyboard-only return with a modifier released outside MT5 separately because its native event sequence is unobserved here.

The missing observations are whether ordinary keys reach the editor and which shortcut/modifier events the affected terminal actually delivers. If the test build still fails, capture a bounded, opt-in, value-free event diagnostic. Do not infer those observations from a selected canvas field, passing C buttons or offline tests.
