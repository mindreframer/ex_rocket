# EPIC003 Plan: Batches And Read Primitives

## Progress

- [ ] Phase 3.1: Implement write batches.
- [ ] Phase 3.2: Implement range deletion.
- [ ] Phase 3.3: Implement multi-get.
- [ ] Phase 3.4: Implement existence checks.
- [ ] Phase 3.5: Add iterator resources.
- [ ] Phase 3.6: Implement all default-CF iterator APIs.
- [ ] Phase 3.7: Test and commit.

## Implementation Steps

1. Decode and execute default-CF batch tuples.
2. Add half-open range deletion.
3. Preserve requested ordering in bulk reads.
4. Match legacy key-may-exist encoding.
5. Safely retain iterator state as a NIF resource.
6. Port full, bounded, and prefix iteration plus `next/1`.
7. Run the full gate and commit `roadmap001 - epic 3 - batches and read primitives`.

## Quality Gate

- [ ] Batch tests pass.
- [ ] Iterator tests pass.
- [ ] Full suite passes.
