# EPIC007 Plan: API Parity, Benchmarks, And Release Readiness

## Progress

- [x] Phase 7.1: Verify public API inventory.
- [x] Phase 7.2: Add dual-backend behavioral parity coverage.
- [x] Phase 7.3: Add error/resource/concurrency coverage.
- [x] Phase 7.4: Add comparative benchmarks.
- [x] Phase 7.5: Complete CI and release wiring.
- [x] Phase 7.6: Complete backend documentation.
- [x] Phase 7.7: Run final gates and commit.

## Implementation Steps

1. Compare `__info__(:functions)` for both modules with documented exclusions only if unavoidable.
2. Parameterize deterministic behavior tests across both modules.
3. Exercise failure paths, resource lifetime, and parallel access.
4. Benchmark equivalent read/write workloads.
5. Add distinct artifact naming and maintained build jobs.
6. Document usage, versions, builds, comparisons, and rollback.
7. Run the final gate and commit `roadmap001 - epic 7 - parity benchmarks and release readiness`.

## Quality Gate

- [x] API parity check passes.
- [x] Full tests pass.
- [x] Both native builds pass.
- [x] Benchmark smoke passes.
- [x] Documentation is complete.
