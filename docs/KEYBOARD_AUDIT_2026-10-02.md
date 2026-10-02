# Numeric keyboard audit and implementation plan

## Scope and boundaries

Fix numeric-field keyboard selection, copying and pasting reported after 1.2.2. Standard numeric editing includes Ctrl+A/C/V/X, undo/redo, arrows, Home/End, Shift selection, deletion, Tab/Shift+Tab, Enter/Escape and numeric keypad input. Numeric fields still reject nonnumeric text. Preserve trading semantics, layouts, persistence and C buttons. The October 2 audit phase excludes desktop control, interactive clipboard tests, live trades, production installation, commits, push and publication. The separately authorized October 3 rollout is recorded below.

## Live plan

1. Completed: inspect clean current feature checkout, applicable instructions, event/controller/editor/platform paths and previous proof boundaries. No repository-local AGENTS.md exists. Current source and latest historical release identify 1.2.2.
2. Completed: nine executed production-function cases failed for the expected modifier, paste, cut, history and navigation assertions before changes. No native MT5 event observation is claimed. Additional fault-boundary coverage continues with verification.
3. Completed: current terminal key state supplies modifiers per event. The clipboard reader bounds UTF-16 allocation and requires a terminator. Numeric paste validates the complete replacement before insertion. Cut deletes only after successful copy; undo/redo uses bounded field-session history. Standard selection and clipboard aliases are handled without changing trading rules. Initial targeted cases pass.
4. Completed for the available offline boundary: final Python suite passes 489 tests and safely skips two private-station fixtures. Four Go packages pass uncached normally and with race detection; vet succeeds. Both hidden MetaEditor builds report zero errors/warnings and all 12 copied source hashes match. The diff is reviewed, the narrow changed-file privacy scan passes, and no released or canonical binary is changed. Native MT5 event delivery and DLL marshalling remain unverified.
5. Completed: findings, key contract, private evidence links and exact native/rollout limits are recorded. Local reviewable changes remain uncommitted; no release or installed binary is replaced. The final diff and JUnit totals are reviewed.

## Findings and acceptance

| ID | Severity and impact | Evidence / root cause | Acceptance | Status |
|---|---|---|---|---|
| KB01 | High usability: Ctrl shortcuts and Shift selection can fail when modifier events are absent or focus changes | LotCraft.mq5 only updated g_ctrl_down/g_shift_down for virtual key 17/16 events. Prior tests always injected key 17 first. Two new cases reproduced missing-event and stuck-release failures | Current terminal Ctrl/Shift state controls each event; missing modifier down/up sequences cannot disable shortcuts or leave stuck modifiers | Source fix and targeted production-function regressions pass; native queue remains unverified |
| KB02 | High usability: Ctrl+V cannot paste | PS_EditorKey had no Paste result; PS_Platform had no clipboard-reading function. Four replacement/insertion cases reproduced failure | Paste bounded Unicode numeric text at cursor or replace selection. Clipboard access/format/size/parse failures preserve the field and never log pasted data | Source fix and targeted replacement/rejection cases pass; native DLL integration remains unverified |
| KB03 | Medium usability: standard cut, undo/redo and Ctrl navigation/deletion are absent | PS_EditorKey handled Ctrl+A/C only; numeric edits had no history. Three executed cases reproduced cut/history/navigation failures | Cut deletes only after successful transfer; bounded per-editor history supports undo/redo; standard selection/deletion aliases work without changing trading rules | Final function-level key matrix passes, including actual preview/commit/cancel paths, bounded history and redo invalidation. Native acceptance remains unverified |
| KB04 | Medium keyboard access: Tab skips editable Manual account; Shift+Tab from no focus skips the last control | Executed actual traversal reproduced both failures: account was absent from the order, and reverse traversal used a negative initial index one slot too early | Include account only when editable; reverse initial focus reaches the last visible control | Fixed; executed traversal cases pass |
| KB05 | Low reliability/performance: no-op Backspace/Delete reapply the model and recalculate | Executed boundary-deletion case failed its no-recalculation assertion | Reapply and recalculate only when raw text actually changes; caret/selection can still redraw | Fixed; no-op and unsupported-Ctrl regression passes |
| KB06 | High calculation consistency: undo to incomplete text could retain the later numeric preview | October 3 release review found text-only history; seven executed field cases reproduced the wrong model value after undo to empty text | Undo/redo restores the prior edited-field preview and risk authority without restoring unrelated state or live quotes | Bounded model snapshots accompany text/caret history; seven field regressions and three related history/commit cases pass. Final release gate is recorded separately |

## Primary documentation

- [MT5 terminal key states](https://www.mql5.com/en/docs/constants/environment_state/terminalstatus): key-state properties return GetKeyState-compatible values.
- [MT5 chart events](https://www.mql5.com/en/docs/event_handlers/onchartevent): key events belong to the chart event path.
- [GetClipboardData](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclipboarddata): clipboard handles belong to Windows; lock, read and unlock without freeing or writing them.
- [GlobalSize](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-globalsize): bound reads by the allocated memory size, not an unbounded string copy.

## Verification boundaries

Production-function C++ fixtures exercise the actual source with terminal/Win32 stubs. They do not prove MQL DLL marshalling, UTF-16 string behavior or the native MT5 event queue. Real clipboard tests may run only in a verified private noninteractive window station. Never fall back to the user's clipboard. Only an explicit paste shortcut reads clipboard content in production.

The read-only Hyper-V inventory on this date is permission-blocked. An existing isolated MT5 runtime cannot be established. The private clipboard fixture now tries a unique create-only station when the logon-derived unnamed station already exists; the new attempt is refused with Windows error 5. No existing station is reused, no interactive fallback runs, and no security settings change. The new Win32 clipboard DLL exports resolve successfully in the background.

## Implemented numeric-editor contract

- Ctrl+A selects the field. Ctrl+C or Ctrl+Insert copies only its selected raw text; no selection does not overwrite the clipboard.
- Ctrl+V or Shift+Insert reads Unicode text only on explicit user action. Paste inserts at the caret or replaces the selection. It trims surrounding whitespace and validates the proposed numeric editor text before mutation. Incomplete signs or decimal separators may be edited but cannot be committed as a complete number. One decimal point or comma is accepted; a single comma is always decimal, so `1,234` means `1.234`, not a thousands-grouped value. Currency decoration, internal whitespace, mixed/repeated separators and replacements exceeding 32 characters are rejected unchanged. Use an unformatted number.
- Ctrl+X or Shift+Delete cuts only a selection and only after successful transfer.
- Ctrl+Z undoes; Ctrl+Y or Ctrl+Shift+Z redoes. The field session retains at most 32 snapshots, providing the latest 31 changes. Text, caret and the edited-field model preview are restored together, including incomplete text and risk authority. Unrelated state and live quotes are not rewound. Commit, cancel and beginning another field clear history. New edits after undo discard redo.
- Left/Right move or collapse selection. Ctrl+Left/Right move to numeric-field boundaries. Home/End and Up/Down also reach those boundaries. Shift extends selection. Backspace/Delete remove selected or adjacent characters; Ctrl+Backspace/Delete remove to the field boundary. No-op edits do not reapply or recalculate.
- Tab/Shift+Tab visit visible focus controls, including editable Manual account money but not its read-only Balance/Equity value. Reverse traversal from no focus begins at the last visible control.
- Enter commits and Escape cancels the editor with its existing model validation and rollback. Numeric keypad and decimal characters still pass through the terminal's TranslateKey function. Alphabetic and unrelated shortcuts are not numeric input.

Clipboard reading accepts at most 64 KiB of allocated UTF-16 data and requires a terminator inside that allocation. Every opened/locked failure path closes/unlocks its owned access. Windows retains clipboard memory ownership; this reader never frees, clears or writes that data. Clipboard/model values do not appear in new logs. Plain numeric behavior is shared by all editor fields and themes; no layout or trading code is redesigned.

## October 2 verification evidence

| Check | Observed result | Limit |
|---|---|---|
| Initial red regressions | Nine expected assertion failures, followed by two no-op/focus failures and one reverse-initial-focus failure | Executed production bodies with explicit terminal/clipboard stubs, not observed MT5 delivery |
| Clipboard/controller targeted run | 93 passed before the final commit/cancel case; that final case also passed independently | Actual source algorithms; MQL array syntax adapted where needed |
| Final full Python suite | 489 passed, two skipped in 99.49s; zero failures/errors | Two safe private-station skips report Windows error 5 |
| Clipboard read fault coverage | 22 cases pass, including both handle widths, unavailable format/data, invalid/oversized allocation, allocation/lock failure and missing terminator | Synthetic ownership/size fixtures, not a real UTF-16 round trip |
| System DLL exports | Required new User32/Kernel32 exports resolve | Does not prove the MQL import ABI |
| Go tests / race / vet | Four packages pass uncached normally and with race detection; vet exits 0 | No Go production source changed |
| IC Markets MetaEditor | Zero errors, zero warnings; nonempty EX5, 277258 bytes; all 12 source hashes match | Hidden copied-source compilation only |
| Darwinex MetaEditor | Zero errors, zero warnings; nonempty EX5, 277026 bytes; all 12 source hashes match | Same boundary; separate compiler outputs need not have identical hashes |
| Diff/privacy/preservation | Whitespace check and narrow private-pattern scan pass; separate dirty checkout unchanged | Not a full-history secret audit |
| Release preservation | Canonical EX5 remains SHA-256 `82cef028f783d061049642a4a84aa5ecadf620665611c2ded84fc5578dfb14a6`; released 1.2.2 setup remains `ba73e7d2af59bcc6455d856ed30a74eef3d343e02dd18d1fbc9835af88bdd406` | These historical binaries do not include the new local keyboard fixes |

Local private evidence, excluded from source control and release assets:

- [Final pytest JUnit](../build/keyboard-audit-20261002/pytest-final-results.xml)
- [IC Markets final compiler log](../build/keyboard-audit-20261002/ic-markets-final/LotCraft-compile.log)
- [Darwinex final compiler log](../build/keyboard-audit-20261002/darwinex-final/LotCraft-compile.log)

## Remaining acceptance and rollout

The originally reported native shortcut failure is not certified fixed on affected terminals merely because function tests pass. Test Ctrl+A then Ctrl+C, double-click/drag then Ctrl+C, and Ctrl+V in SL, risk and Manual account fields after deploying the new binary. Check full and partial selections, keypad decimals, cut/undo/redo, Enter/Escape and focus changes, without submitting trades. The [manual matrix](TEST_PLAN.md) records the full contract.

At the end of the October 2 audit, these were local, uncommitted source fixes. Published and installed binaries were not replaced in that phase. No installer, updater, signing key, credential, live terminal, desktop input or user clipboard was modified during that verification.

On October 3, the owner separately authorized final review, background installation and publication as 1.2.3. The [release plan](RELEASE_PLAN_2026-10-03.md) tracks that work; the [release report](RELEASE_1.2.3.md) records fresh evidence. This rollout does not remove the native acceptance limits above.
