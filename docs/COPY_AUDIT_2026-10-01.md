# LotCraft copy audit and implementation plan

## Scope and authority

The initial request authorized a local audit and fixes for objectively confirmed copy defects, not publication or installation. The authoritative worktree started clean on `feat/sl-exposure-ui-hardening` at `12f45edd5da58a72ad046769426b2c3f23689a78`. The published and installed product at audit time was 1.2.1; release artifacts were not changed during the audit. No MQL or MT5 skills were used. The owner later explicitly authorized commits, push and an update; that separate phase is tracked in the [1.2.2 release plan](RELEASE_PLAN_2026-10-01.md) and [release report](RELEASE_1.2.2.md).

Use the existing production-function test harness, primary platform documentation, disposable fixtures and a hidden MetaEditor compilation. A real Windows clipboard test may run only after establishing its own noninteractive window station and desktop. It must never access or modify the user's interactive clipboard, show windows, move the pointer or start a terminal. If isolation cannot be established, report that boundary and do not fall back to the interactive clipboard.

## Live plan

1. Completed: locate the authoritative checkout, inspect instructions/status/build/test conventions, and trace copy buttons and keyboard input through the platform adapter. Fresh status is clean. No repository-local `AGENTS.md` was found.
2. Completed for the available offline boundary: inventoried all copy actions and reproduced eleven failing cases with actual production bodies (nine controller/editor failures and two null-owner failures). Six adjacent controller cases and sixteen platform success/failure cases pass before fixes. Real private-window-station tests compile, but creation is unavailable here; they stop without using the interactive clipboard. This is a native verification limitation, not evidence that every user has the same cause.
3. Completed: fixed the four confirmed defects narrowly after failing regression tests. The targeted production-function suite passes all 33 cases. Risk, trading, persistence, rendering design and version/release behavior remain unchanged.
4. Completed for the final revision: the fresh full run passed 443 tests and skipped two real Windows clipboard tests safely with station-creation error 183. Both installed MetaEditor compilers reported zero errors and warnings for the final sources. All 12 copied source files match the final repository sources for each compiler. Coverage includes all numeric fields and four copy-button hit targets at 96/120/144/192 DPI. The adjacent controller stub name was corrected without weakening its assertions. Final review also reproduced and fixed the stale-checkmark case for failed Ctrl+C after a C-button success. Seven readable production artifacts compare unchanged; Windows security blocks reads of the released installer and installed updater/uninstaller files and was not bypassed.
5. Completed: finalized the inventory, findings, evidence and external/native boundaries. Reviewed the diff and left local source fixes and regression tests only. No commit, push, publication, installation, terminal restart, live trade or interactive clipboard operation was performed.

## Copy inventory and final results

| Surface | Existing action | Path and intended value | Final result |
|---|---|---|---|
| Entry | C button in Full/Compact | `PS_Action` -> `PS_DoCopy` -> `PS_CopyText`; Ask for Instant Long, Bid for Instant Short, model Entry in Pending or if no tick is available | Exact value, symbol precision, missing-tick-size, feedback and scaled hit targets pass |
| SL | C button in Full/Compact | Same path; committed model SL at symbol precision | Exact value, missing-tick-size, feedback and scaled hit targets pass |
| TP | C button in Full/Compact | Same path; committed TP, or formatted numeric zero when disabled | Enabled/disabled values, missing-tick-size, feedback and scaled hit targets pass |
| Position size | C button in Full/Compact | Final calculated volume at symbol volume precision; unavailable sizing is rejected | Millilot precision, unavailable sizing, success/failure feedback and scaled hit targets pass |
| Numeric selections | Custom editor in Full/Compact; risk percentage in Mini | `PS_HandleKeyDown` -> `PS_EditorKey` -> `PS_CopyText` | Whole, partial and reverse selections pass. Ctrl+A then Ctrl+C passes for all seven editor field types, including the hidden legacy commission field. Copy preserves uncommitted raw text and never recalculates |
| Account value | Selectable/editable only in Manual mode | Custom account numeric editor | Raw selected text passes; Equity/Balance display is read-only, with no advertised copy action |
| Target risk and risk percentage | Custom numeric editors | Raw selected text, not currency decoration or abbreviated display | Long input and partially entered selections pass; no-selection Ctrl+C does not overwrite clipboard |
| Actual SL loss, exposure tiles/details, chart labels and status text | Canvas display, no copy command | Not copy-capable in the current product | Do not claim these are native selectable text or add an unrelated copy UI |

Every existing copy action uses the same `PS_PlatformClipboardSet` function. It imports separate 32-bit/64-bit Win32 signatures and transfers movable UTF-16 memory after opening the chart-owned clipboard. It currently makes one `OpenClipboard` attempt. This alone does not prove the users' reported cause. Exact users' button/shortcut, version, permissions and error are not yet supplied.

## Findings

| ID | Severity and impact | Evidence and confirmed root cause | Proposed fix and acceptance | Status |
|---|---|---|---|---|
| CP01 | High usability: selected SL and other numeric text cannot be copied with Ctrl+C | Three executed whole/partial/reverse-selection cases in `tests/test_native_clipboard.py` failed because `PS_EditorKey` in `PS_Editor.mqh` had no Copy result and `PS_HandleKeyDown` in `LotCraft.mq5` had no transfer branch | Copy only the selected raw substring. Preserve editor/selection/model; do not commit, normalize or recalculate. Plain C and Ctrl+C without selection must not overwrite the clipboard | Fixed; targeted production-function cases pass. MT5 event delivery remains unverified |
| CP02 | High data integrity: the C button can copy a different price, including zero | Four executed cases failed: missing tick size turned SL/Entry/TP into zero, and a displayed 128.13 quote on a 0.25 tick was copied as 128.25. `PS_DoCopy` applied trade normalization again while `PS_UIFieldDisplay` only formats the displayed value | Format the displayed/model price directly, without imposing trade eligibility on copying. Keep broker precision, Instant side selection and unavailable-volume rejection | Fixed; exact-value production-function cases pass |
| CP03 | Medium reliability/data loss: an unavailable zero chart handle can clear old clipboard contents before the copy fails | Both 32-bit/64-bit fault-boundary cases showed `PS_PlatformClipboardSet` accepted a successful chart lookup with handle zero, called `EmptyClipboard`, then received a failed transfer. Microsoft documents this null-owner behavior. Occurrence on a user's actual chart is not established | Reject a zero handle before allocating or opening anything. Preserve previous clipboard content. Retain correct transfer/failure cleanup | Fixed; documented-boundary cases pass. Real Windows isolation remains unavailable |
| CP04 | Medium diagnostic accuracy: a failed copy retains the previous success checkmark; the premium canvas does not draw the stored error status | Executed repeated-copy and unavailable-volume cases failed because `PS_DoCopy` reset feedback only on success. Final review reproduced a failed Ctrl+C retaining a prior C-button success. `PS_CopyText` set model status but logged no failure; premium render does not consume that status | Clear prior C-button success on a new button attempt and on any transfer failure. Success feedback only after transfer. Log the generic failure reason with rate limiting and without copying or logging financial text. No UI redesign | Fixed; button and shortcut failure-feedback and no-financial-text logging cases pass |

The initial Windows fixture needed a corrected desktop access constant before it compiled. That compiler failure is a test-fixture error, not a product finding. Attempts to establish a private station failed safely; no interactive clipboard fallback is permitted.

## Verification boundaries

Production-function fixtures do not reproduce the MT5 DLL-import ABI or its event queue. An isolated real Win32 clipboard round trip can verify Windows ownership and UTF-16 content without touching the desktop, but not a particular user's terminal configuration. Broker identity is not evidence of a clipboard cause. Disabled DLL permission, permanent clipboard ownership by another process and Windows policies must remain explicit failures, not false success. Background-copy tests must not log financial values or credentials.

The missing-tick-size cases exercise the copy helper directly. They do not demonstrate that a copy button is reachable during an invalid MT5 startup. The null-owner fixture exercises documented platform behavior, not an observed zero HWND in a user's terminal. None of the confirmed function-level defects proves which defect caused the original third-party report.

## Final verification evidence

| Check | Actual result | Boundary |
|---|---|---|
| Initial controller/editor regressions | Nine failed and six adjacent cases passed before fixes | Compiled production bodies with platform stubs, not source-string checks |
| Initial platform ownership regressions | Two zero-owner cases failed; sixteen success/failure cases passed before fixes | Both 32-bit and 64-bit pointer branches modeled |
| Final-review shortcut feedback regression | Failed on the old common failure path; passed after the two-line reset | Does not change or commit the selected number |
| Dedicated copy coverage | All 41 cases passed in the final full run | Four C actions, seven field types, selection directions and limits, unavailable sizing, Ask/Bid/cached Entry, symbol precision, scaled hit testing, permissions, handle and memory/transfer faults |
| Complete Python suite | **443 passed, 2 skipped** in 67.64 seconds; zero failures/errors | Includes current-source synthetic installer build and other existing regression suites. Standalone Go tests/vet were not rerun because no Go source changed |
| Real Windows clipboard integration | Two fixtures compiled, then skipped: private station creation returned Windows error **183** | No Unicode round trip or real clipboard contention claim. No fallback to the user's clipboard |
| IC Markets MetaEditor | Version 5.0.0.6182; **0 errors, 0 warnings**; nonempty EX5 produced | Hidden compile of copied sources only. Raw process exit code was 1; acceptance uses the compiler summary and actual output, as the existing build does |
| Darwinex MetaEditor | Version 5.0.0.6182; **0 errors, 0 warnings**; nonempty EX5 produced | Same isolated compilation boundary; all 12 copied sources match the final source tree |
| Production preservation | Canonical EA, released EA, embedded payload, both installed EAs and both install manifests match their earlier SHA-256 values | Seven readable artifacts. This does not certify unreadable updater/uninstaller/installer binaries |
| Diff and privacy review | `git diff --check` passed. Production changes are limited to three copy/editor files. No trading, persistence, release version or layout changes | New fixtures contain synthetic numbers only; runtime SID is used only for the private station's DACL and is not logged |
| Isolated VM availability | Read-only Hyper-V inventory denied by the current authorization policy | No permission, credential or machine-policy changes attempted |

Local, ignored evidence:

- [Final pytest JUnit results](../build/copy-audit-20261001-f3a33c4c16c7417fb3b099c7cf209558/pytest-final-results.xml)
- [IC Markets final compiler log](../build/copy-audit-20261001-f3a33c4c16c7417fb3b099c7cf209558/ic-markets-metaeditor-final/LotCraft-compile.log)
- [Darwinex final compiler log](../build/copy-audit-20261001-f3a33c4c16c7417fb3b099c7cf209558/darwinex-metaeditor-final/LotCraft-compile.log)
- [Local evidence index](../build/copy-audit-20261001-f3a33c4c16c7417fb3b099c7cf209558/VERIFICATION.md)

Compiler logs and JUnit contain local paths. Keep this directory private. Do not stage or upload it as a release asset. The two separately compiled EX5 outputs have independent hashes; no canonical/package/installed identity claim is made for the new audit binaries.

## Handoff and remaining dependencies

At audit handoff, the confirmed source defects were fixed and offline acceptance checks passed. The installed product remained 1.2.1 and did not contain these fixes. The later request authorizes a signed 1.2.2 release, not a production installation; consult its separate release report for fresh acceptance and publication status.

For an eventual affected-user check, test all four C buttons with their normal planning values. Select full and partial SL text and press Ctrl+C. Test risk percentage, Target risk and Manual account text without submitting a trade. Paste into a text editor and compare the complete value. Record the exact LotCraft version, Windows/MT5 build, copy action and any generic `clipboard.copy` failure in Experts. Do not share account credentials or financial screenshots.

Live MT5 event delivery, MQL DLL-import marshalling, real Windows UTF-16 round trips and the original user's terminal-specific failure remain unverified. A permitted isolated test environment or owner-run terminal check is needed. No desktop verification was performed.

Windows security refused reads of the existing release installer and installed updater/uninstaller binaries with a malware or potentially-unwanted-software error. This is a separate unresolved security/packaging dependency, not an established cause of SL copying failures. No false-positive assumption, exclusion, protection change or binary replacement was made.

Canvas labels such as Actual SL loss, exposure details and Equity/Balance account displays are not selectable text and have no copy action in the current design. Making these copyable is a new UX feature, not a confirmed regression, and remains outside this fix.

## Primary references

- [OpenClipboard](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openclipboard): opening can fail while another window owns the open clipboard.
- [SetClipboardData](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setclipboarddata): movable-memory transfer and non-null owner requirements.
- [GlobalAlloc](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-globalalloc), [GlobalUnlock](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-globalunlock): allocation, handle/pointer and unlock semantics.
- [Window stations](https://learn.microsoft.com/en-us/windows/win32/winstation/window-stations): each station has a clipboard; only WinSta0 is interactive.
