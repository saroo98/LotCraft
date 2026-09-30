# LotCraft audit and implementation plan

## Live status

1. **Completed:** Locate release worktree, ancestor/repository guidance, branch and unrelated work; inspect build and test entry points.
2. **Completed:** Establish baseline tests and read-only installed/public release evidence; initial source review covers all subsystems. Deep checks continue with each reproducer. Hyper-V inventory is permission-blocked, so no isolated runtime is assumed.
3. **Completed:** F01-F04, F19 and F21 calculation/exposure/market/order fixes implemented. 54 production-function cases and adjacent reference/source checks pass; broker runtime remains unproven.
4. **Completed:** Independent-review F24/F30-F32 repairs pass targeted regression suites (144 capture/UI/controller/Full/static, 172 exposure/UI/risk/static). Final EA source is frozen and audit-staged compilation passed 0 errors/0 warnings in2925ms. Native UI/broker acceptance remains unproven.
5. **Completed:** Installer/updater/build/privacy/key-generation fixes are frozen and targeted tests pass. Documentation is reconciled. No real signing keys, production installations or remote assets were changed.
6. **Completed:** Final frozen-source verification passed: 382 Python cases, all four Go packages normally and with the race detector, `go vet`, 0-error/0-warning EA compilation and diff checks. Final documentation checks passed 79 cases. Production hashes are unchanged. All findings, coverage dispositions, evidence and external boundaries are recorded for review. The initial antivirus block and passing rerun after the user's allowance are recorded without claiming a false positive.

There is no structured plan tool exposed in this session. This file is the live plan and is updated at each phase transition.

Local audit closed for review on 2026-09-10. Native MT5 acceptance, existing remote-asset cleanup and deployment are not complete and are not authorized by this closure. See the audit's external-dependency section. No production or remote change was made.

## Implementation discipline

- The implementation phases run in the listed order. Findings can be investigated in parallel, but fixes require a reproduced defect and agreed scope.
- Record each finding in [the audit](AUDIT_2026-09-09.md) before fixing it.
- Preserve `main` checkout work. Modify only this release worktree.
- Keep changes within the existing product. Ask before new features, major redesign, changed trading semantics or expanded authority.
- Use production behavior tests where feasible. Label native-runtime gaps and model-only/source-string tests honestly.
- Build into audit-owned ignored output. Do not sign a release, create credentials, install, launch the production terminal, or change remote state.
- Keep local environment details out of tracked evidence. Never copy signing keys, account data or raw production logs into audit documents.

## Per-finding execution template

1. Capture source location and a discriminating fixture.
2. State the invariant, root cause and user impact.
3. Write and run a failing regression before the production edit.
4. Implement the smallest coherent fix.
5. Run the regression and adjacent checks. Record exact results and scope of proof.
6. Review the diff, update finding status, and continue.

## Final acceptance

- All requested audit areas have a recorded disposition.
- Confirmed defects are fixed and evidenced, or tied to a specific external dependency.
- Python and Go suites and available static checks run against the final tree.
- MetaEditor build is attempted safely, without live UI verification or production changes.
- Installer tests use synthetic temporary installations, not real terminal folders.
- Report versions and update timing truthfully. Do not promise a notification deadline not implemented by the scheduler.
- Compare installed file hashes before and after; verify the unrelated checkout is unchanged.
- Deliver audit, live plan and [verification evidence](AUDIT_VERIFICATION_2026-09-09.md), with optional improvements ranked by value and effort.
