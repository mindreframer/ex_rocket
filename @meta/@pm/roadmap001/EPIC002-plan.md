# EPIC002 Plan: Database Lifecycle And Core KV

## Progress

- [ ] Phase 2.1: Port baseline option decoding.
- [ ] Phase 2.2: Implement open and read-only open.
- [ ] Phase 2.3: Implement destroy and repair.
- [ ] Phase 2.4: Implement database metadata.
- [ ] Phase 2.5: Implement put and delete.
- [ ] Phase 2.6: Implement get and Elixir helpers.
- [ ] Phase 2.7: Test and commit.

## Implementation Steps

1. Decode existing option maps into maintained `Options`.
2. Return independent DB resources from both open variants.
3. Schedule blocking maintenance work appropriately.
4. Expose path and latest sequence number.
5. Add binary writes and deletes.
6. Add binary reads, defaults, and Erlang-term decoding.
7. Run the full gate and commit `roadmap001 - epic 2 - lifecycle and core kv`.

## Quality Gate

- [ ] Lifecycle tests pass.
- [ ] KV tests pass.
- [ ] Legacy tests pass.
- [ ] Native build passes.
