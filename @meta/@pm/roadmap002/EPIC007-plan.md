# EPIC007 Plan: Failure Verification And Release Readiness

## Progress

- [ ] Phase 7.1: Verify the end-to-end checkpoint protocol.
- [ ] Phase 7.2: Execute the complete failure matrix.
- [ ] Phase 7.3: Run concurrency and native-lifecycle stress.
- [ ] Phase 7.4: Publish comparative operational benchmarks.
- [ ] Phase 7.5: Build and smoke-test the precompiled artifact matrix.
- [ ] Phase 7.6: Complete package and release preparation.
- [ ] Phase 7.7: Run final gates and commit.

## Implementation Steps

1. Test durable dirty/data/clean writes and source-cursor authorization across independent process lifetime.
2. Cover failures around every marker/data boundary, close, and live iterator/snapshot ownership with expected recovery actions.
3. Mix readers, writers, paged iterators, snapshots, CF work, close attempts, and path reopen cycles under repeated stress/sanitizers.
4. Publish 0.4.1/0.5.0 point, batch, iterator, memory, close, and BEAM-heartbeat results with hardware, OS, data, options, cache state, and concurrency context.
5. Build, checksum, load, bind, and smoke-test Apple ARM64/x86-64, Linux ARM64/x86-64 glibc/musl, and Windows x86-64 artifacts.
6. Finalize versions, package contents, changelog/docs, ADR status, upgrade/rollback guidance, workflow, and checksums without publishing.
7. Run the final gate and commit `roadmap002 - epic 7 - complete failure and release verification`; only then authorize 0.5.0.

## Quality Gate

- [ ] Failure and checkpoint matrices pass.
- [ ] Concurrency/race stress passes.
- [ ] Benchmarks are published with reproducible context.
- [ ] Every configured artifact builds and smoke-tests.
- [ ] Package and release documentation are complete.
- [ ] Complete source and release gates pass.
- [ ] Only EPIC007 changes are committed.
