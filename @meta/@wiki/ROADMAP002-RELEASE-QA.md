# ROADMAP002 Release QA Record

## Local Source And Failure Verification

**Date:** 2026-08-04

- Clean Rust 1.91 source build completed for ExRocket 0.5.0.
- Elixir and Rust formatting passed.
- `cargo check --locked` passed.
- 123 ExUnit tests passed.
- The independent-BEAM failure matrix passed for:
  - before the durable dirty marker;
  - after dirty;
  - during projection writes;
  - before clean;
  - after clean/cursor advancement;
  - process termination after explicit close.
- Mixed default/CF readers, writers, snapshots, paged iterators, close attempts,
  and immediate reopen completed across ten stress rounds.
- EPIC005's 250 repeated child-creation/close races remain green.
- The functional raw-NIF smoke test exercised strict options,
  `write_batch/3`, `flush_wal/2`, `iterator_take/2`, `close/1`, and post-close
  errors.
- `mix hex.build` produced the 0.5.0 package with `OPTIONS.md` and
  `UPGRADING.md` included.
- Comparative release benchmarks and their complete environment/context are
  recorded in `ROADMAP002-BENCHMARKS.md`.

## Precompiled Artifact Matrix

GitHub Actions preflight run
[`30873598651`](https://github.com/mindreframer/ex_rocket/actions/runs/30873598651)
built and functionally smoked every target before the 0.5.0 tag:

| Target | Build | Functional smoke | Preflight SHA-256 |
| --- | --- | --- | --- |
| `aarch64-apple-darwin` | passed | passed | `bc9948fca8cdd4aada4d54cca7be98d63f59f0d9098d1c03191a50913f47b0ed` |
| `x86_64-apple-darwin` | passed | passed | `87ff934d72a2093c15b3e5883f7cc29ac393f238e8d38ab103ca7b2aedcc34c6` |
| `aarch64-unknown-linux-gnu` | passed | passed | `4675689088ba62d79d80202a12ffd583a17d912494db6f53218a43c55455d971` |
| `aarch64-unknown-linux-musl` | passed | passed | `df3d6871b6db937f111cb19e3251628d6fd0675212a1cf2f73f8c8198d56e4ac` |
| `x86_64-unknown-linux-gnu` | passed | passed | `1600c158dbffa8f0a32fbffcc1d59df638dd3a06ae5f71b36888ab7c2fea3df7` |
| `x86_64-unknown-linux-musl` | passed | passed | `c2f7e587e44468fc19e03dcd1f8ce54ca3b0ad16072d49728669879b0a088a1e` |
| `x86_64-pc-windows-msvc` | passed | passed | `111b79aa6644d0b0b7788cb6e6fee356280fa0e7b1f19dba3dc9636bd3a0d583` |

The final published checksums are regenerated from the tag workflow artifacts,
because archive metadata can differ between builds. Release completion still
requires a green tag workflow, all seven GitHub release assets, and a successful
local precompiled download.
