# LotCraft 1.2.4 release evidence

The owner authorizes meaningful commits, normal push and a signed stable release on 2026-10-03. The [release plan](RELEASE_PLAN_2026-10-03_1.2.4.md) records current work. Previous release reports are historical evidence, not proof that this package or every native shortcut works.

## Correction

Both observed build-6230 terminals delivered Ctrl presses and A/C/V/X/Z releases without the corresponding shortcut-letter presses. The old release ignored those commands. The correction retains event-time modifier and editor context, dispatches a release-only command through the existing editor path and suppresses duplicate commands when the press was delivered. It tracks independently held left/right modifiers and uses the existing frame timer for editor painting.

A subsequent native reset trace identified the final Ctrl+A defect: a chart-layout event erased the saved Ctrl gesture while the same numeric editor was still active. Removing that blanket layout reset preserves select-all; actual symbol, focus and lifecycle changes still invalidate it. The captured-path replay failed in three cases before the correction and passed afterward.

No diagnostic probe is included. Numeric validation, C buttons, risk/trading semantics, layouts, persistence schema and update timing are unchanged. EA, installer and signed-release identities advance to 1.2.4.

## Evidence boundary

The [keyboard investigation](KEYBOARD_RELEASE_EVENT_FIX_2026-10-03.md) records the native cause and earlier local tests. The owner reports copy, paste, cut and undo working in the local correction. The final Ctrl+A correction has no explicit owner-run native acceptance result yet. Production-function replay is not native MT5 UI, DLL marshalling or broker certification.

## Fresh package verification

| Check | Observed result | Boundary |
|---|---|---|
| Focused release checks | 147 passed; one stale version assertion failed, was aligned to 1.2.4, and passed its narrow rerun | Version expectation changed without relaxing its assertion |
| Full Python suite | 560 passed, two skipped in 128.81s; zero failures/errors | Private station creation denied with Windows error 5; no interactive fallback |
| Go | All four packages pass uncached normal and race tests; vet exits zero | Disposable test boundaries, not native UI |
| IC Markets compiler | Zero errors/warnings; canonical EX5 283,280 bytes | Hidden compilation, not terminal execution |
| Darwinex compiler | Zero errors/warnings; separate EX5 282,942 bytes; all 12 copied source hashes match | Separate compiler outputs can differ; package embeds canonical IC Markets build |
| Signed package | Ed25519 signature, exact installer descriptor and PE 1.2.4.0 verify against unchanged pinned key | Not Authenticode signing |
| Embedded installation | Fresh install and signed-public-1.2.3-to-1.2.4 upgrade both exit zero; exact four-file schema-2 inventories and matching EX5/helper hashes | No payload override; disposable terminal-like directories, not the owner's production installs |
| Release verifier | Canonical, staged and fixture-installed EX5 hashes match; signed descriptor verifies | Public JSON's installed role is the disposable upgrade fixture |
| Windows security scan | Custom scan exits zero, reports no threats and no matching detection records for this package | Does not certify other machines or reclassify older detections |
| Privacy and preservation | Narrow scan of 26 changed files finds no private-pattern matches; public metadata has no absolute paths; embed placeholder and pinned key match original hashes | Heuristic scan, not a full-history secret audit; separate dirty checkout and installed production copies remain unchanged |

Both compiler logs were read in full. MetaEditor can exit 1 despite a clean summary and fresh output; this is not represented as exit-zero compiler evidence. No diagnostic probe is in canonical or packaged source. Private raw evidence remains in ignored build output.

## Artifacts

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `LotCraft-1.2.4-Setup.exe` | 6,948,352 | `39e46fa08e530411fe698e664e120084e9eeccd630505b317bc081b777b72e6f` |
| `LotCraft-1.2.4-SHA256.txt` | 91 | `9c4227fcbf6e10c79c7f984c3e2292c6fbe5e39cd30fdc498061be9ac7313916` |
| `LotCraft-update.json` | 256 | `e1dbea6a240a440e6fed2134e3cf2e7f736a52169893857a119ce85df9095579` |
| `LotCraft-update.sig` | 89 | `58adcf1fb4b5169ad76f2bfbaad4ee8bf29ca5bfa982986c64bf2e2db6467966` |
| `RELEASE-VERIFICATION.json` | 2,116 | `d809da22ff46917f1929150afce998380f9692b2a1d10e6582c5c4dc291ab59d` |
| `LotCraft.ex5` (embedded, not uploaded separately) | 283,280 | `2e9d53b80be48f3614cfdf6129f9c8457161442d9a6ef86dab5b7a195850700c` |

Only the first five artifacts are public assets. The EX5 is embedded in the self-contained setup. All uploaded sizes and digests matched local bytes before draft publication. Fresh anonymous downloads of all five assets match those same sizes and SHA-256 values. The downloaded descriptor and signature verify against the unchanged pinned Ed25519 key, the checksum text matches the downloaded setup, and its PE identity verifies as 1.2.4.0.

## Public updater verification

The production anonymous Checker was exercised against the published release with its existing host allowlist and pinned key. Installed-version inputs 1.2.0 and 1.2.3 both produce the signed 1.2.4 candidate. The 1.2.3 case downloads and verifies the 6,948,352-byte installer with the SHA-256 above. Installed-version input 1.2.4 correctly produces no newer candidate. The uncached delivery smoke test passes in 1.50s.

This verifies release discovery, version ordering, signature validation and installer download through production functions. It does not exercise the scheduling, prompt, installed updater state or native activation. No token, terminal input or production installation was used. The temporary network-test harness and output remain in ignored evidence; the harness was removed from production source after the check.

## Publication

[LotCraft 1.2.4](https://github.com/saroo98/LotCraft/releases/tag/v1.2.4) is latest stable, published at 2026-10-03T13:28:16Z. Three meaningful commits separate keyboard source/regressions, native diagnostic evidence and release identity/documentation. The normal atomic push updated main and the feature branch to `8106cb985d593add6b0a49b3b052c2b4ce84043d`. The annotated v1.2.4 tag peels to that tested source. Previous release tags and assets are unchanged. No private key, raw log, terminal identifier or local installation manifest is a release asset.

The final delivery-evidence follow-up changes documentation only. It does not move the release tag, change package bytes or install into the owner's terminals.

## Update timing and safety

A functioning verified installation can offer the newer signed release at its next eligible check. EAs from 1.2.1 onward provide ten-second startup and hourly launch opportunities. The updater allows an attempt only after 24 hours since its previous attempt, including failures. No defers the same offered version for 24 hours. Publication cannot guarantee a notification for every user within 24 hours.

Updates do not restart MT5. Reattach LotCraft or restart MT5 later to activate installed bytes. Missing helpers, offline terminals, invalid installations, missing DLL permission, network failures and security blocks can delay or prevent an offer.

The signature uses the existing pinned Ed25519 key. It is not Authenticode signing and does not establish that an antivirus detection is a false positive. Do not bypass Windows protection. The custom scan result above applies only to this check; prior detections remain historical security evidence.
