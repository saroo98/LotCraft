# LotCraft 1.2.3 release and installation plan

## Authority and boundaries

The owner requests final review, installation and complete publication of the keyboard fixes. Use patch version 1.2.3 and the existing pinned Ed25519 key. Commit task-owned source and documentation in meaningful groups, push without force, and publish the five normal stable-release assets. Preserve the separate dirty checkout and all unrelated work. Install quietly into the previously specified IC Markets Global and Darwinex terminals only after resolving their data directories from origin.txt and verifying existing ownership.

Do not control the desktop or interactive clipboard, launch or restart MT5, place trades, change credentials, bypass Windows protection, or use MQL/MT5 skills. Native keyboard delivery and MQL clipboard marshalling remain unverified without an accessible isolated runtime. A passing offline suite does not establish that every affected terminal works.

## Live plan

1. Completed: recover the source checkout, current changes, build/release contracts and release authority. Latest stable is v1.2.2. Both verified production directories contain 1.2.1 EX5 and manifests; the updater and uninstaller files are absent. Existing installer recovery permits absent owned files while checking every present file. The existing signing key has a protected current-user-only DACL. IC Markets is running; Darwinex is not running. The separate dirty checkout is unchanged.
2. Completed: independent read-only review found one Important text-only-undo preview defect and no Critical issue. Seven real-ApplyRaw field regressions failed before correction, then passed; the clipboard/read/controller suite passes 101 tests. Bounded preview snapshots now restore only the active field and coupled risk authority/source values. The reviewer found no remaining Critical/Important issue. Source/test/current documentation identities are 1.2.3; historical reports and persistence namespaces are preserved. Domain-invalid and live recalculation effects remain source-checked, not native runtime proof.
3. Completed: 496 Python tests pass with two private-station skips (Windows error 5), zero failures/errors. Four Go packages pass uncached normally and with race detection; vet exits 0. IC Markets and Darwinex hidden MetaEditor compilers report zero errors/warnings; all 12 source hashes match. The signed 1.2.3 package passes PE, Ed25519 and descriptor checks. Custom Windows security scan exits 0 with no matching detections. Disposable embedded installation exits 0 with exactly four schema-2 files and matching canonical/staged/installed EX5 and helper hashes. The tracked embed placeholder is restored; private raw evidence stays ignored.
4. Completed: both IC Markets and Darwinex upgrade quietly from 1.2.1 to 1.2.3, with installer exit 0 and exact four-file schema-2 inventories. Canonical, staged and both installed EX5 hashes match; updater/uninstaller hashes match the signed setup. Previously absent helpers are restored through the existing verified ownership/recovery path. Private original-file backups remain ignored. IC Markets retains its original running process; Darwinex remains stopped. No loaded EA is activated automatically.
5. Completed: three meaningful task-owned commits pushed atomically to main and the feature branch without force. Annotated v1.2.3 peels to verified source commit 6afc5c6190e630ebc6d3d70684d4cb88bb16cbcc. All five draft asset sizes/digests matched local bytes before publication. GitHub stable/latest is v1.2.3, published at 2026-10-02T23:15:51Z. No private paths, raw logs, installation manifests or keys are public assets.
6. Completed: all five fresh public downloads match local sizes/hashes, and downloaded signed metadata verifies against the unchanged pinned key. The anonymous production Checker sees signed 1.2.3 from current version 1.2.2, verifies its installer download and returns no newer candidate for 1.2.3. Its temporary smoke harness is removed; private output remains ignored. Public evidence and timing limits are recorded. Documentation-only commits synchronize both branches without moving the release tag. Native acceptance and universal notification remain unproven.

## Acceptance

- Standard numeric selection, copy/paste, cut, undo/redo, navigation and focus preserve domain validation, C buttons, trading behavior and privacy.
- No unresolved Critical or Important review finding enters the release.
- Required tests pass; safe-isolation skips are explicit. Compiler errors and warnings are zero.
- The signed installer embeds the same EX5 installed into both production destinations. The exact four-file ownership inventory and schema 2 are valid.
- The latest stable GitHub release is v1.2.3. Its five assets match local size and SHA-256, and its signature verifies against the unchanged pinned key.
- A production Checker running anonymously for 1.2.2 sees 1.2.3; a checker for 1.2.3 sees no newer release.
- Native shortcut acceptance is reported as unproven, and activation requires user reattachment or a later normal restart.

## Update timing

Working installations provide hourly launch opportunities after the initial ten-second launch. Network attempts are throttled for 24 hours, including failures; No defers that version for 24 hours. Missing helpers, invalid installations, missing DLL permission, offline terminals and network failures prevent an offer. Publishing cannot force every user to receive a notification within 24 hours. This local installation restores the normal helper inventory through the verified installer, not a protection bypass.
