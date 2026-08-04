# EPIC001 Plan: Contract Baseline And Validation Harness

## Progress

- [ ] Phase 1.1: Capture the API and native implementation inventory.
- [ ] Phase 1.2: Add focused behavioral baseline tests.
- [ ] Phase 1.3: Add public types, specs, stubs, and exact result shapes.
- [ ] Phase 1.4: Define the stable error vocabulary.
- [ ] Phase 1.5: Correct terminal, option, and durability documentation.
- [ ] Phase 1.6: Add `scripts/roadmap002_check.sh`.
- [ ] Phase 1.7: Run gates and commit.

## Implementation Steps

1. Inventory public arities, NIF exports/schedulers, resource ownership, option decoders, and relevant returns.
2. Freeze existing write-batch, iterator, snapshot, path-lock, GC-close, option, and terminal semantics in tests.
3. Define `write_batch/3`, `iterator_take/2`, and `close/1`; confirm `flush_wal/2` support before including its contract.
4. Add programmatic atoms/structures for closed, busy, invalid new options, and unknown keys.
5. Fix `:end_of_iterator`, canonical option examples, and atomicity-versus-durability explanations.
6. Implement the clean gate with `RUSTUP_TOOLCHAIN=1.91.0`, both format checks, `mix clean`, `FORCE_BUILD=yes mix compile --warnings-as-errors`, and `FORCE_BUILD=yes mix test`.
7. Run the full gate and commit `roadmap002 - epic 1 - establish consistency contracts`.

## Quality Gate

- [ ] API/native inventory is complete.
- [ ] Baseline and contract tests pass.
- [ ] Documentation corrections are complete.
- [ ] Clean source-build script passes.
- [ ] Full suite passes.
- [ ] Only EPIC001 changes are committed.
