# LotCraft 1.2.1 release plan

## Authority and boundaries

The owner authorizes meaningful commits, pushing the current project work, a polished and search-friendly README, and publication of a signed 1.2.1 release after verification. Private data is excluded. The separate dirty main checkout stays untouched. No live trades, desktop control, MT5 launch, production installation, key generation or key rotation is authorized. Release signing may use the existing private key without printing or uploading it.

## Live plan

1. Completed: review the complete pending inventory, public/private boundaries, default branch ancestry, release tooling and updater timing. The default branch can be fast-forwarded without touching the dirty main checkout. One tracked plan workspace path is replaced with a repository-root placeholder. The existing signing key is present; no key contents were printed.
2. Completed: periodic detached update opportunities pass the three executed scheduler cases and four adjacent contracts. Current EA/installer/PE/build/test identities are aligned to 1.2.1 without changing persistence namespaces. README now uses clear MT5 position-sizing terms, direct install/update guidance and truthful risk/runtime limits. Current product documents match the hourly opportunity/daily throttle contract.
3. Completed locally: 402 Python tests with no skips, four Go packages normally/with race, Go vet, MetaEditor zero errors/warnings, signed descriptor verification, actual embedded-payload disposable install, placeholder restoration and five-asset privacy checks pass. Exact results and hashes are in the release report. Public/native acceptance is not inferred from these gates.
4. Completed: thirteen cohesive commits are pushed to the feature branch and default branch without force or modifying the dirty main checkout. Annotated tag `v1.2.1` points to `4054fd16e5ea578b9072e31116944bf7cd185601`. New commit metadata uses the authenticated owner's public GitHub noreply email; account credentials and global Git configuration are unchanged.
5. Completed: stable `v1.2.1` is published as latest with exactly five assets. Each public download matches its verified local size and SHA-256. The production Go Checker, run anonymously without a popup or installer execution, accepts 1.2.1 for current version 1.2.0, verifies the signed descriptor and downloaded setup, and suppresses an equal-version candidate. Publication time is `2026-09-30T08:22:04Z`; native notification delivery is not inferred.
6. Completed, explicitly approved: only the older v1.2.0 `RELEASE-VERIFICATION.json` was replaced with a path-redacted copy. Seven path fields became artifact basenames; all non-path evidence is unchanged. The other four asset IDs, sizes, digests and upload states, plus release identity, publication time and notes hash, are unchanged. The public replacement download matches the redacted copy; the original backup remains private and ignored.
7. In progress, final push only: public verification and report-only privacy repair are recorded; eight production hashes and the separate dirty checkout match baseline. Final diff review, 79 documentation/static contracts, eight README local links and a narrow scan of 57 changed source files/six public assets pass. Push this evidence, verify the remote refs and README, then record completion without changing the release tag.

## Notification contract

- A push is not an EA update. The installed updater needs a newer stable signed release.
- Version 1.2.1 will launch a detached updater ten seconds after initialization and provide recurring opportunities while the EA stays attached. The updater retains its installation-scoped mutex and 24-hour network-attempt throttle, including failures.
- Old installed EAs cannot be rescheduled remotely. Version 1.2.0 users need a normal reattachment or MT5 restart before their next eligible check, or can install 1.2.1 manually.
- Offline machines, missing DLL permission, modified installations, daily deferral, network failures and closed MT5 prevent a universal notification deadline. Do not promise every user a popup within 24 hours.
- Updates still require Yes/No approval. They do not place trades or restart MT5. The new EA activates after reattachment or a later restart.

## Commit groups

Keep changes together by behavior: trading/risk/session validation; exposure data integrity; numeric editor; per-symbol plans and controller recovery; DPI/marker/rendering behavior; installer rollback/ownership; updater worker verification/cleanup; signing-key protection; test harness and behavior coverage; public build evidence privacy; audit documentation; update cadence; 1.2.1 identity; README and release guidance. Combine coupled files when splitting would make a commit misleading. Do not manufacture commit count by separating one change into meaningless fragments.

## Acceptance evidence

Record fresh Python/Go/race/vet results, zero-warning MetaEditor diagnostics, canonical/staged EX5 hashes, installer PE metadata, signed manifest/installer size/hash agreement, unchanged embedded placeholder, disposable installation hashes, staged privacy checks, pushed refs, and public release asset verification in the release report. Native MT5 popup, rendering and broker acceptance remain explicitly unverified.
