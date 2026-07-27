# EPIC003 Plan: Batches And Read Primitives

## Progress

- [x] Phase 3.1: Implement write batches.
- [x] Phase 3.2: Implement range deletion.
- [x] Phase 3.3: Implement multi-get.
- [x] Phase 3.4: Implement existence checks.
- [x] Phase 3.5: Add iterator resources.
- [x] Phase 3.6: Implement all default-CF iterator APIs.
- [x] Phase 3.7: Test and commit.

## Implementation Steps

1. Decode and execute default-CF batch tuples.
2. Add half-open range deletion.
3. Preserve requested ordering in bulk reads.
4. Match legacy key-may-exist encoding.
5. Safely retain iterator state as a NIF resource.
6. Port full, bounded, and prefix iteration plus `next/1`.
7. Run the full gate and commit `roadmap001 - epic 3 - batches and read primitives`.

## Quality Gate

- [x] Batch tests pass.
- [x] Iterator tests pass.
- [x] Full suite passes.
