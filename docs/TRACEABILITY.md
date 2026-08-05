# LotCraft 1.1.0 Requirements-to-Implementation Traceability

Source authority: the supplied **Build Prompt: LotCraft v1.0.0 for MetaTrader 5**.

Status terms:

- **Implemented, automated evidence**: source exists and an offline deterministic or source-contract test passes.
- **Implemented, native evidence pending**: source exists, but the behavior requires MetaEditor, MT5, Windows, or a broker demo server for acceptance.
- **Not produced**: the required native artifact could not be generated in this environment and is not claimed.

## 1. Identity and clean implementation

| ID | Requirement | Implementation | Evidence/status |
|---|---|---|---|
| ID-01 | Product, source, compiled name, title, logs, installer, and metadata identify `LotCraft 1.1.0` | `LotCraft.mq5`, `PS_Types.mqh`, UI title, log helpers, installer constants/resources | Implemented, automated identity and PE tests |
| ID-02 | Clean implementation independent of old Position Sizer | Dedicated source tree, `LotCraft.v100` objects, `LotCraft.100` state, dedicated installer path | Implemented, automated source/installer scans |
| ID-03 | Multiple instances do not collide | Prefix hash includes account server/login and chart ID | Implemented; native multi-chart evidence pending |

## 2. Exact visible control inventory

| Prompt item | Internal control(s) | Behavior/module | Evidence/status |
|---:|---|---|---|
| 1 | `PS_CTRL_MANUAL` | Isolated Win32 F9 request only; no order send | Implemented; native dialog evidence pending |
| 2 | `PS_CTRL_MINI` | Full/mini toggle, state retained and persisted | Implemented; repeated native toggle pending |
| 3 | `PS_CTRL_CLOSE` | `ExpertRemove()` only | Implemented; native cleanup evidence pending |
| 4 | `PS_CTRL_DIRECTION` | Long/Short transition preserves distances and recalculates | Implemented, calculation tests; native UI pending |
| 5 | `PS_CTRL_ENTRY_FIELD` | Custom keyboard editor; Instant market-bound, Pending durable | Implemented, editor/source tests; native keyboard pending |
| 6 | `PS_CTRL_ENTRY_MINUS`, `PS_CTRL_ENTRY_PLUS` | One tick per click; timer acceleration; Pending only | Implemented, source contract; native hold timing pending |
| 7 | `PS_CTRL_ENTRY_COPY` | Normalized Entry to Unicode clipboard | Implemented; Windows/MT5 evidence pending |
| 8 | `PS_CTRL_STOP_FIELD` | Custom keyboard editor and immediate model update | Implemented, editor tests; native keyboard pending |
| 9 | `PS_CTRL_STOP_MINUS`, `PS_CTRL_STOP_PLUS` | Tick-size step and accelerated repeat | Implemented; native hold timing pending |
| 10 | `PS_CTRL_STOP_COPY` | Normalized SL to clipboard | Implemented; Windows/MT5 evidence pending |
| 11 | `PS_CTRL_TAKE_FIELD` | Custom editor; zero or committed empty disables TP | Implemented, editor/calculation tests; native pending |
| 12 | `PS_CTRL_TAKE_MINUS`, `PS_CTRL_TAKE_PLUS` | Tick-size step and accelerated repeat | Implemented; native hold timing pending |
| 13 | `PS_CTRL_TAKE_COPY` | Normalized TP/zero to clipboard | Implemented; Windows/MT5 evidence pending |
| 14 | `PS_CTRL_ORDER_MODE` | Instant/Pending only; pending subtype inferred | Implemented, all subtype tests |
| 15 | `PS_CTRL_LINES` | Show/hide owned lines without discarding values | Implemented; native chart evidence pending |
| 16 | `PS_CTRL_COMMISSION_MODE` | One side or Round trip account-currency money per lot | Implemented, calculation tests |
| 17 | `PS_CTRL_COMMISSION_FIELD` | Custom nonnegative numeric editor | Implemented, editor/calculation tests |
| 18 | `PS_CTRL_ACCOUNT_MODE` | Equity, Balance, Manual cycle | Implemented, authority/mode tests |
| 19 | `PS_CTRL_ACCOUNT_FIELD` | Read-only live basis except stored editable Manual value | Implemented, editor/source/mode tests |
| 20 | `PS_CTRL_RISK_PERCENT_FIELD` | Percentage becomes risk authority | Implemented, authority tests |
| 21 | `PS_CTRL_RISK_MONEY_FIELD` | Money becomes risk authority; live currency label | Implemented, authority/source tests |
| 22 | `PS_CTRL_ACTUAL_PERCENT` | Read-only actual percentage | Implemented, calculation/source tests |
| 23 | `PS_CTRL_ACTUAL_MONEY` | Read-only actual money | Implemented, calculation/source tests |
| 24 | `PS_CTRL_POSITION_SIZE` | Read-only broker-valid lots | Implemented, calculation/source tests |
| 25 | `PS_CTRL_POSITION_COPY` | Normalized lot size to clipboard | Implemented; Windows/MT5 evidence pending |
| 26 | `PS_CTRL_MOVE_SLS` | Move every valid current-symbol position/pending-order SL to the exact red line | Implemented, mocked/source tests; demo pending |
| 27 | `PS_CTRL_CONFIRM` | Persistent single-toggle boolean | Implemented, source test; redraw/native pending |
| 28 | `PS_CTRL_TRADE` | Only new-order control; direction and volume in text | Implemented, source/mocked tests; demo pending |
| UI-X | No additional visible controls | Custom labels/boxes only; exact enum inventory; no EA inputs, native buttons, edits, tabs, or menus | Implemented, automated inventory scan |

## 3. Chart levels and pointer behavior

| ID | Requirement | Implementation | Evidence/status |
|---|---|---|---|
| LIN-01 | One Entry, SL, optional TP line | Three owned HLINE objects; TP hidden at zero | Implemented, source test; native pending |
| LIN-02 | Lines permanently nonselectable/non-draggable | Central `PS_UIApplyLineLock`, repeated enforcement | Implemented, source test; native drag evidence pending |
| LIN-03 | Dedicated full-body single-press handles | Separate rectangle-label hit regions and explicit capture | Implemented, source test; native pending |
| LIN-04 | Continuous handle-line coupling | Pointer motion updates model, recalculation, render, line and handle together | Implemented; native latency/coupling pending |
| LIN-05 | Handles only when line enabled, globally visible, and in viewport | `PS_UIUpdateLines` derives visibility from all three conditions | Implemented, source test; native resize/zoom pending |
| LIN-06 | Correct attachment after chart changes | chart-change dirty layout/line projection and periodic lock | Implemented; native matrix pending |
| PTR-01 | Panel before handles before chart | Controller performs panel hit test first, then handles | Implemented, source test; native fall-through pending |
| PTR-02 | Capture survives pointer leaving interface/chart and restores settings | Saved chart flags plus Win32 pointer/button fallback | Implemented, source test; native pending |
| PTR-03 | Interface and backing objects never show selection borders | All owned UI objects nonselectable/nonselected | Implemented; native double-click pending |

## 4. Editing and focus

| ID | Requirement | Implementation | Evidence/status |
|---|---|---|---|
| ED-01 | One-click focus and immediate valid-keystroke recalculation | Panel mouse press begins custom editor; `PS_EditorApplyRaw` on each changed key | Implemented, editor/source tests; native pending |
| ED-02 | Preserve raw text and safe incomplete states | Separate raw string; parser flags incomplete text without model mutation | Implemented, editor tests |
| ED-03 | Enter, Escape, click-away | Explicit commit/cancel paths and model snapshot rollback | Implemented, editor/source tests; native click paths pending |
| ED-04 | Locale convention | Accepts `.` and `,`, canonicalizes to `.` | Implemented, editor tests |
| ED-05 | Backspace/Delete/navigation/selection replacement | Custom key state machine, Shift selection, Ctrl+A, Home/End | Implemented, editor/source tests; native keyboard pending |
| ED-06 | Read-only outputs cannot edit | No field mapping for actual risk or position size | Implemented, source test |
| ED-07 | No native edit artifacts | No `OBJ_EDIT`; custom caret/selection objects reused | Implemented, source test; native residual-object pending |

## 5. Risk and price calculation

| ID | Requirement | Implementation | Evidence/status |
|---|---|---|---|
| CALC-01 | Live broker/account data, no pip/contract/currency hard-coding | `PS_MarketAcquire` reads required MT5 properties | Implemented, source tests; live broker validation pending |
| CALC-02 | Correct executable Entry and pending subtype | Ask/Bid Instant; four pending comparisons | Implemented, subtype tests |
| CALC-03 | Robust one-lot loss and account conversion | `OrderCalcProfit()` at one lot | Implemented, source/reference tests; native symbols pending |
| CALC-04 | Consistent commission | One-side doubled; round-trip once | Implemented, calculation tests |
| CALC-05 | Downward broker-volume normalization | cap, floor lattice, min rejection, actual-risk postcheck | Implemented, calculation/source tests |
| CALC-06 | Min/max/aggregate volume policy | cap max/remaining direction limit, reject below min | Implemented, calculation tests |
| CALC-07 | Actual risk from final volume | Recomputed money and percentage | Implemented, calculation tests |
| CALC-08 | Risk authority under changing account values | Authoritative view retained; dependent view recalculated | Implemented, authority tests |
| PRICE-01 | Long/Short SL/TP invariants | Central protective-price validation | Implemented, calculation tests |
| PRICE-02 | Stops/freeze and ambiguous pending rejection | Central broker-distance validation | Implemented, calculation tests; server check pending |
| PRICE-03 | No silent reversal or level movement | Invalid state blocks trading; transitions are explicit | Implemented, source/calculation tests |
| PRICE-04 | Different-symbol prices are rebuilt while Direction/mode survive | `PS_PersistenceLoad`, `PS_ModelBuildFreshSymbolPlan`, `PS_RefreshMarket`, `OnInit` | Implemented, reference and source-contract tests; user visual check pending |
| PRICE-05 | Same-symbol timeframe changes preserve the complete plan | Symbol-hash guarded atomic Entry/SL/TP persistence and structural restore | Implemented, source-contract tests; user visual check pending |
| PRICE-06 | Instant-to-Pending preserves SL and cannot begin quote-ambiguous | Candidate Limit/Stop construction with buffered broker/tick distances | Implemented, reference and source-contract tests; user visual check pending |
| PRICE-07 | Automatic Entry/SL spacing cannot collapse after normalization | Outward ceiling-to-tick placement plus 0.2%/100-tick/broker/34-pixel gap | Implemented, calculation tests |
| PTR-04 | Stop owns overlapping Entry/Stop pixels for paint and input | Stop-first hit priority, higher z-order, final paint order, fixed capture enum | Implemented, source-contract tests; user visual check pending |

## 6. Trading and modification safety

| ID | Requirement | Implementation | Evidence/status |
|---|---|---|---|
| TRD-01 | Refresh/recalculate immediately before send | Fresh market snapshot and request rebuilt | Implemented, mocked/source tests |
| TRD-02 | Connection, permission, session, trade mode, price, volume, fill/time validation | `PS_TradePermissions`, risk validation, filling/expiration selection, `OrderCheck` | Implemented, mocked/source tests; broker demo pending |
| TRD-03 | Duplicate and in-flight guard | 750 ms submit gate and in-flight boolean | Implemented, mocked tests |
| TRD-04 | Actual server retcode determines success | accepted-retcode allowlist after `OrderSend` | Implemented, mocked tests; demo pending |
| TRD-05 | Complete confirmation and no-send cancellation | snapshot text contains every required field; cancel returns | Implemented, source/mocked tests; native dialog pending |
| TRD-06 | Reconfirmation on material change | one updated confirmation, second change abort | Implemented, mocked/source tests |
| SLM-01 | Explicit exact-line SL batch | every valid position/pending order on the current symbol, both directions, exact red-line replacement | Implemented, mocked/source tests |
| SLM-02 | Per-entity revalidation and partial results | reselect ticket, revalidate live values, one request/result per target | Implemented, mocked/source tests; demo pending |
| SLM-03 | Preserve unrelated properties | live TP and pending entry/stoplimit/time/fill copied | Implemented, source/mocked tests |
| SLM-04 | Hedging/netting handling | ticket-level positions; conservative new-order block when existing nonhedging position | Implemented, model/source tests; demo pending |

## 7. State, lifecycle, performance, and errors

| ID | Requirement | Implementation | Evidence/status |
|---|---|---|---|
| LIFE-01 | Persist only allowed state | allowlisted terminal globals; no prices | Implemented, source test |
| LIFE-02 | Correct cleanup and restoration | timer kill, chart-property restore, proven prefix deletion | Implemented, source test; native lifecycle pending |
| LIFE-03 | No collision or unrelated deletion | unique prefix and dedicated persistence namespace | Implemented; native multiple-instance pending |
| PERF-01 | Stable object reuse and dirty rendering | create once; update properties; direct manipulation render; coalesced timer refresh | Implemented, source inspection; native stress pending |
| PERF-02 | Internal budgets and release-light diagnostics | defined microsecond budgets, diagnostics disabled | Implemented, source inspection |
| ERR-01 | Coherent failures and prefixed logs | finite checks, explicit return paths, rate-limited `LotCraft` logs | Implemented, source tests; runtime log review pending |

## 8. Deliverables and packaging

| ID | Requirement | Artifact | Status |
|---|---|---|---|
| ART-01 | All `.mq5`/`.mqh` source | `MQL5/Experts/LotCraft/` | Delivered |
| ART-02 | Required runtime resources | None required | Delivered as documented |
| ART-03 | Architecture document | `docs/ARCHITECTURE.md` | Delivered |
| ART-04 | Build/install document | `docs/BUILD_AND_INSTALL.md` | Delivered |
| ART-05 | Traceability table | This file | Delivered |
| ART-06 | Test plan/evidence | `docs/TEST_PLAN.md`, `docs/TEST_EVIDENCE.md` | Delivered; native sections pending |
| ART-07 | Known limitations | `docs/KNOWN_LIMITATIONS.md` | Delivered |
| ART-08 | Clean compiled EX5 | `MQL5/Experts/LotCraft/LotCraft.ex5` | Produced by Darwinex MetaEditor, `0 errors, 0 warnings` |
| ART-09 | Windows installer | `build/LotCraft-1.1.0-Setup.exe` | Rebuilt and PE-tested; local installation is part of the release gate |
| ART-10 | Four required SHA-256 hashes | `release/LotCraft-1.1.0/RELEASE-VERIFICATION.json`, release verifier outputs | Canonical, staged, and installed EX5 hashes must match; installer hash recorded |
| PKG-01 | Dedicated safe install/upgrade/uninstall | Go installer and manifest | Automated policy/PE evidence plus Windows clean-install, upgrade, protected-refusal, and uninstall smoke passes |
| PKG-02 | No source in end-user installer | installer owns only EX5, uninstaller, manifest | Implemented, automated test |

## 9. Acceptance status

Source contracts, deterministic domain behavior, mocked trade safety, installer
policy/PE structure, native MetaEditor compilation, Windows installer execution,
and EX5 hash equality pass. Full native chart-interaction acceptance is not
claimed because the saved demo-account authentication dialog requires user
interaction before the remaining MT5 pointer and lifecycle matrix can run.
