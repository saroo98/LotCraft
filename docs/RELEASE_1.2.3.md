# LotCraft 1.2.3 release evidence

The owner authorizes final keyboard review, background installation into the two previously specified terminals, commits, push and stable signed publication on 2026-10-03. The [release plan](RELEASE_PLAN_2026-10-03.md) records live status. The [keyboard audit](KEYBOARD_AUDIT_2026-10-02.md) records the confirmed source defects and existing native proof boundaries.

## Changes

Current terminal key state controls each key event. Numeric editors add validated paste, successful-transfer-only cut, bounded session undo/redo, standard selection/navigation/deletion and corrected Tab order. C buttons, trading semantics, layouts, persistence and updater cadence remain unchanged. EA, installer, PE metadata and signed-release identities advance to 1.2.3.

The final read-only review found a text-only undo defect: restoring incomplete text retained the later numeric preview. Seven real-ApplyRaw regressions failed before correction and passed afterward. Bounded model snapshots now restore the edited field and, for risk editors, the coupled risk authority/source values without rewinding unrelated settings or live quotes. The targeted clipboard/read/controller suite passes 101 tests. No Critical or Important issue remains in the reviewed source. Domain-invalid and real recalculation/quote interactions are source-checked, not native runtime evidence.

## Verification status

| Check | Fresh observed result | Boundary |
|---|---|---|
| Independent review | One Important undo-preview defect corrected; no remaining Critical/Important source finding | Read-only review, not native MT5 acceptance |
| Python suite | 496 passed, two skipped in 100.66s; zero failures/errors | Both private-station clipboard fixtures report Windows error 5; no interactive fallback |
| Go tests and vet | Four packages pass uncached normally and with race detection; vet exits 0 | Disposable fixtures; no live trade |
| IC Markets MetaEditor | Zero errors/warnings; canonical EX5 is 281,064 bytes | Hidden compilation, not terminal execution |
| Darwinex MetaEditor | Zero errors/warnings; separate EX5 is 279,732 bytes; all 12 source hashes match canonical sources | Separate compiler outputs need not have identical hashes; package uses canonical IC Markets build |
| Signed package | PE 1.2.3.0, Ed25519 signature and installer descriptor verify | Existing pinned key unchanged; not Authenticode signing |
| Windows security scan | Exit 0, no matching detection records; setup readable and executable | Does not certify other machines or reclassify older detections |
| Embedded-payload fixture | Installer exit 0; exactly four schema-2 files, EX5 matches canonical/staged, helpers match setup | No explicit payload override; disposable terminal-like folder |
| Production installation | IC Markets and Darwinex each upgrade 1.2.1 to 1.2.3 with exit 0, exact four-file inventories, valid schema-2 manifests and matching payload/helper hashes | Background disk installation only; IC Markets retains its running process and Darwinex remains stopped |
| Release verifier | Required production-installed role matches canonical/staged and signed descriptor | Public JSON's installed role refers to IC Markets; Darwinex is independently checked above |
| Privacy/preservation | 26 changed source/doc candidates have no narrow private-pattern matches; whitespace check passes; tracked embed placeholder restored | Heuristic, not full-history secret audit; raw evidence and original-install backups stay ignored; separate dirty checkout preserved |

Local private evidence is under ignored `build/release-audit-20261003`. No raw logs, terminal paths, local manifests or keys are release assets.

## Artifacts

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `LotCraft-1.2.3-Setup.exe` | 6,945,792 | `6417e113ff528788ecbca8c827bc323eaf6b582cb63743ae07d9729a525e9d4e` |
| `LotCraft-1.2.3-SHA256.txt` | 91 | `f0f40eca4f75248b7f32918a8a659c10399be646dc9744e6b6a77d952d350e94` |
| `LotCraft-update.json` | 256 | `38d1bb0112e9872f31513dc5b1a57c5e590038ba3e26b2bcffaf41243ff19b2b` |
| `LotCraft-update.sig` | 89 | `8af89c935fb18dcc701da2674b133ccddc5f0951f061777fee6b9fffb9561e26` |
| `RELEASE-VERIFICATION.json` | 2,116 | `029941d575462028cbb910740820c2ffde89fa6b049bcdbf880cd4cd183bb01e` |
| `LotCraft.ex5` (embedded, not uploaded separately) | 281,064 | `9ffc6ef1c77bfe049e7b4b24c5d072d309c65568873bf857cd852dc31b39639a` |

The public release contains only the first five assets. Publication and fresh public download/update detection checks are next; no remote result is claimed yet.

## Native and activation limits

No desktop control, interactive clipboard access, live MT5 UI test or trade is performed. Source-extracted function tests and clean compiler builds cannot prove native event delivery or MQL DLL marshalling. The user must reattach LotCraft or later restart MT5 normally to activate newly installed bytes. Installation on disk does not replace an already-loaded EA in memory.

## Update timing

A verified installation with a functioning updater can offer a newer stable release at its next eligible check. Hourly launch opportunities and the 24-hour network-attempt throttle are unchanged. Offline or stopped terminals, missing DLL permission, missing helpers, invalid installations and deferral can delay or prevent an offer. Publication cannot guarantee every user's notification within 24 hours.
