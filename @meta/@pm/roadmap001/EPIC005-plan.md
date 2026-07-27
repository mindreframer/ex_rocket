# EPIC005 Plan: Snapshots, Checkpoints, And Backups

## Progress

- [ ] Phase 5.1: Add snapshot resources.
- [ ] Phase 5.2: Implement default snapshot reads.
- [ ] Phase 5.3: Implement CF snapshot reads.
- [ ] Phase 5.4: Implement snapshot multi-get.
- [ ] Phase 5.5: Implement snapshot iterators.
- [ ] Phase 5.6: Implement checkpoints and backups.
- [ ] Phase 5.7: Test and commit.

## Implementation Steps

1. Retain snapshots safely with their originating DB.
2. Port get/default behavior.
3. Resolve CFs through the snapshot owner.
4. Preserve multi-get result ordering.
5. Reuse maintained iterator resources for snapshots.
6. Port checkpoint and complete backup APIs.
7. Run the full gate and commit `roadmap001 - epic 5 - snapshots checkpoints and backups`.

## Quality Gate

- [ ] Snapshot tests pass.
- [ ] Checkpoint tests pass.
- [ ] Backup tests pass.
- [ ] Full suite passes.
