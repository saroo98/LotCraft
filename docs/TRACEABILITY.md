# LotCraft 1.2.1 current implementation traceability

Authority is the current owner request, applicable instructions, and current source. SOURCE_SPECIFICATION.txt is the historical 1.0.0 starting specification. Later approved behavior supersedes conflicting details. This table describes implementation and proof boundaries, not blanket runtime acceptance.

| Area | Current contract and source | Evidence / remaining proof |
|---|---|---|
| Identity | EA, installer and release scripts identify 1.2.1; persistence namespace remains compatible | Current source/PE checks and release report; native activation remains unverified |
| Risk/currency | PS_Risk uses broker OrderCalcProfit conversion and volume lattice; Target risk and Actual SL loss are separate | Production-function and reference fixtures; live broker conversion pending |
| Minimum volume | Positive below-minimum requests can use minimum volume subject to capacity; actual risk can exceed target | Calculation fixtures; not every amount is tradable |
| Planning/readiness | sizing_available permits cached-quote planning; valid additionally requires execution gates | Production readiness/session fixtures; closed-market runtime pending |
| Exposure | PS_Exposure uses position entry or pending fill, including stop-limit limit leg; downside-only totals and current-equity percentages | Production stop-limit/count-drift tests and reference aggregation fixtures |
| Missing data | Missing-SL/unavailable states; failed refresh/copy invalidates snapshot; known amounts are not complete totals | Production controller, allocation and UI summary tests |
| Trade entry | Explicit final action; magic zero; one optional risk-only confirmation; refreshed validation before check/send | Source/model checks and production transition guards; server acceptance pending |
| SL modification | Separate current-symbol batch path, fresh ticket validation and per-ticket results | Production collection/confirmation/allocation/distance fixtures; demo execution pending |
| Full controls | Left/right Long/Short and Instant/Pending choices; selected/gap/cross-choice release does nothing |26 production pointer/control cases; native clicks pending |
| View/account selectors | Current view selected; Compact interaction retained; Equity, Balance, Manual basis | Source/geometry checks; native matrix pending |
| Editing |32-character replacement limit, numeric authority, measured viewport, caret/selection/hit mapping | Production editor/UI fixtures and reference parser tests; UTF-16/keyboard runtime pending |
| Clipboard/steppers | Copy feedback and accelerated price steppers remain in controller/platform code | Source review; Windows clipboard/hold timing pending |
| Persistence | Preferences plus per-symbol Direction/mode/Entry/SL/TP; legacy migration; mode changes keep SL/TP fixed | Actual storage/controller/mode-cycle fixtures; native restart/partial-write recovery pending; no crash-atomic or indefinite-retention claim |
| Symbol recovery | New symbol uses new-scale prices; failed transition can return to original plan; hidden focus cannot activate | Production controller fixtures; multi-chart event runtime pending |
| Markers | Owned locked lines, DPI-scaled handles, S before E before TP; Instant E drag changes to Pending | Geometry/allocation/source tests; actual overlap/drag pending |
| Rendering | Dirty/cached surfaces, bounded failure retry, invisible failed targets disabled | Production failure/retry and mutation tests; native flicker/stress pending |
| Exposure surfaces | One details canvas, up to128 open-position label canvases bounded by available height, height-derived page capacity, cached symbol precision | Geometry/precision tests; not one combined label canvas |
| Themes/layout | Shared DPI tokens, bounded text, measured tile insets, corrected active-button contrast | Deterministic metrics/contrast; font rasterization/visual acceptance pending |
| Commission | Engine arithmetic remains; current UI omits commission controls and startup uses zero | Source review; not advertised as an available control |
| Installer/updater | Four owned files, path/hash checks, staged replacement, rollback, stable signed metadata; first launch after ten seconds, then hourly opportunities with a daily network-attempt throttle | Go synthetic Windows fixtures, current-source PE and actual scheduler tests; native popup/activation separate |
| Privacy | Ignored local artifacts/credentials; public-safe report generation under audit | Heuristic scan and synthetic path-leak tests; existing remote asset needs cleanup approval |

## Evidence

- [September 30 audit and implementation plan](AUDIT_2026-09-30.md)
- [September 30 offline evidence](AUDIT_VERIFICATION_2026-09-30.md)
- [Current release plan](RELEASE_PLAN_2026-09-30.md)
- [1.2.1 release verification](RELEASE_1.2.1.md)
- [Earlier audit findings](AUDIT_2026-09-09.md)
- [Future isolated acceptance matrix](TEST_PLAN.md)

The production-function harness executes extracted source with deterministic platform stubs and documented C++ syntax adapters. Static source-string checks remain useful contracts but are not runtime proof. No historical build, installed binary or screenshot is relabeled as current evidence.
