# 0.5.0 - Unreleased

- Added explicit batch durability through `write_batch/3` and synchronous or
  non-synchronous WAL boundaries through `flush_wal/2`.
- Added bounded `iterator_take/2` pages with entry/payload limits and stable
  snapshot/iterator continuation.
- Moved storage- and lock-backed native operations to dirty I/O schedulers.
- Added idempotent `close/1` with safe iterator/snapshot lease handling and
  stable `:closed`/`:resource_busy` errors.
- Corrected iterator terminal and database-option documentation.
- **Breaking validation change:** unknown database, read, write, and iterator
  option keys now return `{:error, {:unknown_option, key}}` instead of being
  silently ignored. Malformed database/read values identify the invalid key.
- Added canonical option and 0.5.0 migration references. Existing RocksDB files
  require no migration.

# 0.4.1 - 2026-07-27

- Reworked the README with concise, tested examples for key/value operations,
  atomic batches, multi-get, and column families.
- Added prominent links to the comprehensive ExRocket cheatsheet.
- Explicitly included `CHEATSHEET.md` in Hex package and ExDoc output.

# 0.4.0 - 2026-07-27

- Updated the native storage integration to `rust-rocksdb 0.51`, bundling
  RocksDB 11.1.2.
- Preserved the established `ExRocket` API.
- Added precompiled NIFs for ARM64 and x86-64 Linux with glibc or musl, including
  Alpine Linux smoke tests.
- Raised the source-build requirement to Rust 1.91.

# 0.3.1

- Dependencies: Upgraded rust-rocksdb from 0.22.0 to 0.24.0
  - Latest RocksDB features and performance improvements
  - Enhanced stability and bug fixes from upstream
- Build Requirements: Updated minimum Rust version to 1.85+
  - Required for rust-rocksdb 0.24.0 compatibility
  - Ensures access to latest Rust compiler optimizations
- CI/CD Improvements: Added comprehensive caching to GitHub Actions
  - Mix dependencies caching for faster builds
  - Rust/Cargo dependencies caching
  - Build artifacts caching for improved CI performance
  - Updated actions to latest versions (@v4)


- Added comprehensive RocksDB merge operator support
  - Three merge operators: counter, erlang term, and bitset
  - Support for tuple-based operations: `{:int_add, value}`, `{:list_append, list}`, `{:binary_append, data}`, etc.
  - Column family merge operations with `merge_cf/4` and `merge_cfb/4`
- Added binary helper functions for ETF serialization
  - `getb/2` and `get_cfb/3` for automatic term deserialization
  - `mergeb/3` and `merge_cfb/4` for automatic term serialization
- **NEW**: Merge operations support in batch writes
  - Added `{:merge, key, operand}` and `{:merge_cf, cf, key, operand}` to `write_batch/2`
  - Atomic batch operations combining puts, deletes, and merges
- Added comprehensive cheatsheet documentation (`CHEATSHEET.md`)
- Complete test coverage for all merge operations

# 0.2.0

- Allow binary in multi_get
- Improve build scripts
- Delete checksum file from git
- Added licence and changelog
- Bump deps to current versions

# 0.1.0

- Initial release