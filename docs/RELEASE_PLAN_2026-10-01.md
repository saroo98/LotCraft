# LotCraft 1.2.2 release plan

## Authority and boundaries

The owner explicitly requests committing all current LotCraft copy-audit changes, pushing them and publishing an update. Prepare patch version 1.2.2 from the current feature worktree. Exclude private data, ignored binaries/logs, credentials and signing keys. Preserve the separate dirty checkout. Use the existing pinned signing key only; do not generate or rotate credentials. No production installation, terminal restart, desktop control, live trade or interactive clipboard access is authorized.

## Live plan

1. Completed: inspect current changes, instructions, remote default branch and release tooling. Latest stable is v1.2.1; remote main matches the current base commit. The existing key has a protected DACL with no other-user Allow rule. New commits will use the authenticated owner's public GitHub noreply identity without changing Git configuration.
2. Completed: EA, installer, PE metadata, tests and current product documentation identify 1.2.2. Persistence namespaces, trading behavior and updater cadence remain unchanged. Historical 1.2.1 records are retained.
3. Completed: fresh Python verification passed 443 tests with two explicitly limited private-station skips. Four Go packages passed uncached normally and with race detection; vet completed with exit 0. Signed release build, zero-warning compilation, checksum/PE/signature verification and disposable embedded-payload installation pass. New-setup custom security scan reports no matching detection records. Thirty current source/asset candidates pass the narrow privacy scan. The first fixture was correctly rejected for missing a normal terminal marker; its corrected config marker succeeds without weakening validation.
4. Completed: three meaningful implementation, identity and documentation commits were pushed atomically to the feature and default branches without force. Annotated v1.2.2 targets verified code commit 4b83bdfee7f43025c629c09c335a056e0abb889e. The stable signed release contains exactly the five intended assets.
5. Completed: latest-release API identifies v1.2.2, published at 2026-10-01T10:02:16Z. All five freshly downloaded assets match local sizes and SHA-256 values. The anonymous production Checker verifies the signed candidate and installer for current version 1.2.1 and returns no update for 1.2.2. Remote branch and peeled tag identities match. See the release report for verification boundaries. Final evidence documentation is committed separately without moving the release tag.

## Release contract

- Publish the setup, versioned checksum, signed update JSON, detached signature and path-redacted verification JSON.
- Do not publish the EX5 separately, local raw logs, installation manifests, terminal paths or private test evidence.
- A working installed updater can offer 1.2.2 at its next eligible check. Version 1.2.1 provides hourly launch opportunities with a 24-hour network-attempt throttle. Older EAs can require reattachment or restart. Offline, disabled-DLL, blocked, modified or deferred installations have no guaranteed deadline.
- Windows security currently blocks reads of some existing 1.2.1 helper binaries. This is not proven to cause clipboard failures. Do not assume a false positive or modify protection settings. If the new release is blocked or cannot be verified, do not publish it.
