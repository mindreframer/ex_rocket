# Unreleased

- Replaced the unmaintained `rocksdb 0.24` binding with maintained
  `rust-rocksdb 0.51`, bundling RocksDB 11.1.2.
- Bound the established `ExRocket` API directly to the maintained native backend.
- Removed the duplicate legacy Rust crate, temporary migration module, duplicate
  tests, and release artifacts after the unchanged legacy test suite passed
  against the new backend.
- Added representative bidirectional RocksDB 10.4.2/11.1.2 migration checks.
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