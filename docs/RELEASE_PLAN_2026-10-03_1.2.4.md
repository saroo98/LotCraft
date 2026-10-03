# LotCraft 1.2.4 signed release plan

## Authority and boundaries

The owner explicitly requests meaningful commits, normal push, deployment and a signed release so installed updaters can discover the correction. Use patch version 1.2.4 and the existing pinned Ed25519 key. Do not move or replace prior release tags or assets. Preserve the worktree and the separate dirty checkout.

No desktop control, terminal restart, live trade, security-setting change, credential creation, production reinstallation or MQL/MT5 skill use is included. Verify the self-contained installer in disposable terminal-like directories. Keep private key bytes, raw logs, terminal identifiers and local manifests out of commits and public assets.

## Live sequential plan

1. Completed: identify the authoritative feature worktree, current dirty files and release contracts. Both remote main and feature branch initially point to 0c81bbe. The latest stable is 1.2.3. The existing key has a protected current-user-only DACL; the pinned public key is unchanged.
2. Completed: prepare 1.2.4 identity changes across EA, installer, PE resources, build scripts, verifier, identity tests and current installation documentation. Keep persistence schema and updater cadence unchanged. Prepare three meaningful commit groups: keyboard source/regressions; diagnostic findings/evidence; version and release documentation.
3. Completed: 560 Python tests pass with two private-station skips (Windows error 5); all four Go packages pass uncached normal/race tests and vet exits zero. Both hidden compiler logs have zero errors/warnings. Signed metadata, descriptor, PE 1.2.4.0 and pinned key verify. A Windows custom scan reports no threats and no matching detection records. Fresh embedded installation and 1.2.3-to-1.2.4 embedded upgrade exit zero with exact four-file schema-2 inventories and matching EX5/helper hashes. All 12 source copies match, the embed placeholder is restored, narrow privacy checks on 26 changed files find no matches, and whitespace/diff checks pass.
4. Completed: three meaningful commits separate keyboard source/regressions, native diagnostic evidence and release identity/documentation. Normal atomic push updates main and the feature branch to 8106cb985d593add6b0a49b3b052c2b4ce84043d; annotated v1.2.4 peels to that tested source. All five draft asset sizes/digests match local bytes. Latest stable is v1.2.4, published at 2026-10-03T13:28:16Z. Prior tags/assets are unchanged.
5. Completed: fresh anonymous downloads of all five public assets match local size/SHA-256. The downloaded Ed25519 signature, descriptor, checksum and PE identity verify. The production anonymous Checker offers signed 1.2.4 from 1.2.0 and 1.2.3, downloads/verifies the installer, and offers no newer candidate from 1.2.4. No installed updater state or terminal input was used. The temporary harness was preserved in ignored evidence and removed from production source.
6. Final delivery review: executable and test source match the release tag; all 12 compiled source copies and public artifacts still match. The pinned key and embed placeholder are unchanged. The separate dirty checkout retains its original changes. The delivery-evidence follow-up contains documentation only; its normal push does not move the release tag, rebuild assets or modify production installations. Final remote and worktree checks are retained in ignored evidence.

## Completion criteria

- No diagnostic probe is in canonical or packaged source.
- Required tests pass and both compiler logs have zero errors/warnings. Skips are explicit, not passes.
- Signed metadata identifies exactly 1.2.4/v1.2.4 and the final setup size/SHA-256. The pinned public key is unchanged.
- Embedded installation and verified upgrade produce exactly four schema-2 files with matching EX5/helper hashes.
- The final push is non-forced and retains unrelated work. The release tag identifies the tested source.
- All five public assets match local bytes. The production Checker detects signed 1.2.4 from older installed versions and no newer candidate from 1.2.4.
- Native Ctrl+A acceptance stays unproven unless the owner explicitly reports it. A signed release is not native UI or malware certification.

## Update delivery

Publication makes a newer signed version eligible; it cannot force a universal notification. Current EAs provide a launch after ten seconds and hourly thereafter. The updater throttles attempts for 24 hours, including failures. No defers the offered version for 24 hours. Missing helpers, invalid manifests, missing DLL permission, offline terminals, blocked binaries or network errors can prevent an offer. The new EA activates after reattachment or a later normal restart.
