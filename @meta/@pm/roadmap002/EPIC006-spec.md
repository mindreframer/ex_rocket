# EPIC006 Spec: Exact Configuration And Documentation

## Purpose

Make accepted options, validation, examples, errors, and operational semantics exact enough to prevent silent production misconfiguration.

## Scope

Canonical database/read/write/iterator option inventory; unknown-key and value validation; reference documentation; executable examples; ExRocket 0.5.0 migration guidance.

## Out Of Scope

Undocumented aliases, generated documentation tooling, new RocksDB options, or convenience write arities.

## Acceptance Criteria

- One authoritative inventory records every accepted public option, type, default, native mapping, and documentation status.
- Database, read, write, and iterator decoders reject unknown keys as `{:error, {:unknown_option, key}}` before opening or mutating resources.
- Invalid values and combinations have test-defined programmatic errors and never panic native code or require RocksDB-string parsing.
- Every documented option is accepted; every accepted public option is documented or explicitly designated internal.
- README, cheatsheet, module docs, and examples use exact native option names and only `:end_of_iterator`.
- Documentation covers durability levels, iterator bounds/status, dirty scheduling, close behavior, stable errors, and the distinction between `sync` and `set_use_fsync`.
- Executable examples pass, and 0.5.0 guidance explains strict validation, configuration auditing, compatibility, rollback, and synchronous checkpoint selection.

## Test Strategy

Use inventory-driven checks, unknown/misspelled/malformed options, representative executable examples, and scans for stale names and terminal atoms.

## Quality Gate

Run the roadmap source gate, option inventory/validation tests, documentation checks, executable examples, and full compatibility tests before commit.
