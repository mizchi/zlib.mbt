# Changelog

All notable changes to this project will be documented in this file.

## [0.4.5] - 2026-05-19

### Security
- **Bound decompressed output size.** All `*_decompress` / `*_decompress_at`
  entry points now accept a `max_size?` labeled argument (default
  `default_max_decompressed_size`, 256 MiB) and raise
  `ZlibError::OutputTooLarge` rather than allowing unbounded allocation.
  This closes a "zip bomb" vector where a tiny crafted deflate stream
  could otherwise expand to gigabytes via repeated back-references.
- **Tighter dynamic-tree parsing.** `build_dynamic_trees` rejects
  code-length repeat codes (16/17/18) that would overrun the declared
  `hlit + hdist` table, and rejects code 16 with no previous length
  (RFC 1951 conformance).
- **Permissive zlib header.** `zlib_decompress_stored_at` now accepts any
  CMF whose CM nibble is 8 (instead of requiring exactly 0x78) and
  rejects FDICT, matching `zlib_decompress_at`.

### Added
- `ZlibError::OutputTooLarge(String)` variant.
- `default_max_decompressed_size` public constant.

### Changed
- `ZlibError` derives only `Eq`; `Show` is implemented manually to drop
  the deprecated `derive(Show)`.
- Re-applies the `mizchi/zlib/native` split from 0.4.4 on top of the
  hardened pure-MoonBit core. `mizchi/zlib` itself is pure MoonBit on
  every target (including `native`); dependents that want the C FFI
  backend import `mizchi/zlib/native`, which links `-lz` internally.

### Note
- 0.4.2/0.4.3/0.4.4 were published to mooncakes.io from a working copy
  whose commits never made it back to GitHub. 0.4.5 reconstructs the
  0.4.4 native split from the registry tarball and re-bases the 0.4.1
  security work on top of it.

## [0.4.4] - 2026-04-09

### Changed
- Keep `mizchi/zlib` pure MoonBit on `native` as well as `js`/`wasm`.
- Add explicit `mizchi/zlib/native` package for system zlib C FFI usage.
- Remove the need for dependents to add `-lz` when using the default package.

> Released to mooncakes.io only; the underlying commits never made it
> back to the GitHub repo. Reconstructed retroactively in 0.4.5.

## [0.3.0] - 2026-01-29

### Added
- Deflate compression (fixed Huffman + LZ77).
- Dynamic Huffman encoding with code-length RLE.
- `deflate_compress`/`zlib_compress` now produce compressed output and select the smaller of fixed/dynamic blocks.

## [0.2.0] - 2026-01-28

### Added
- Bench CLI (`src/cmd/bench`) for native/wasm/wasm-gc runs.
- Rust baseline benchmark tool (`tools/rust_bench`) using flate2/miniz_oxide.
- `scripts/bench_compare.sh` and `just bench-compare` for side-by-side comparisons.
- wasm/wasm-gc results to the benchmark table in the README.

### Changed
- BitReader now uses a 64-bit buffer with batched reads for faster bit extraction.
- Huffman decode uses a 2-level table for fewer branches in the hot path.
- Benchmark table updated with the latest measurements.

## [0.1.0] - 2026-01-28

- Initial release.
