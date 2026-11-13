# Migrating to MoonBit core

`mizchi/zlib` 0.4.11 is the final release. For new projects, use the codecs
included in MoonBit core since v0.10.19:

- [`moonbitlang/core/compress/flate`](https://mooncakes.io/docs/moonbitlang/core/compress/flate)
- [`moonbitlang/core/compress/zlib`](https://mooncakes.io/docs/moonbitlang/core/compress/zlib)
- [`moonbitlang/core/compress/gzip`](https://mooncakes.io/docs/moonbitlang/core/compress/gzip)

These packages are currently experimental. Add
`options("allow-experimental-packages": true)` to the importing `moon.pkg`.

| mizchi/zlib API | core replacement |
| --- | --- |
| `deflate_compress` / `deflate_compress_best` | `@flate.deflate_all` |
| `zlib_compress` | `@zlib.compress` |
| `gzip_compress` / `gzip_compress_stored` | `@gzip.compress(input, strategy=Standard(level=0))` to retain stored compression |
| `deflate_compress_stored` / `zlib_compress_stored` | The corresponding compressor with `strategy=Standard(level=0)` |
| `deflate_decompress` | `@flate.inflate_exact` |
| `zlib_decompress` | `@zlib.decompress` |
| `gzip_decompress` | `@gzip.decompress`, subject to the differences below |
| `deflate_decompress_at` | Slice the input at `start`, call `@flate.inflate_prefix`, and add `start` to the returned `consumed` |
| zlib/gzip `*_decompress_at` | The corresponding streaming `Decoder`, with consumption and unused input tracked by the caller |

Preserve these application-level contracts explicitly:

- **Output limits:** this library defaults to 256 MiB. Core defaults to its
  Bytes capacity. Pass an explicit limit when migrating. The November 5
  toolchain uses `max_output`; current core main renamed it to
  `max_output_bytes` and retains the old label as a migration alias.
- **Gzip boundaries:** this library decodes one member and rejects trailing
  input. Core's whole-buffer gzip decoder joins members and ignores trailing
  bytes that do not start another member. Use `Decoder(multistream=false)` and
  validate consumed and unused input if strict single-member behavior matters.
- **Compression output:** core's algorithms and compressed bytes differ.
  This library's `gzip_compress` emits stored blocks; core defaults to level 6.
  There is no direct public fixed-Huffman-only strategy corresponding to
  `deflate_compress_fixed`.
- **Errors:** replace matches on this library's `ZlibError` with the separate
  flate, zlib, or gzip error types and classifications.
- **Standalone checksums and libz:** there is no direct public core replacement
  for this library's Adler-32/CRC-32 functions or its explicit system-libz
  native wrapper. Core's `internal/checksum` package is not a public API.
  Retain a small compatibility layer if these are needed.

The final release remains available for existing applications. This repository
will receive no further maintenance. Its stored-size calculation has been
ported upstream in [moonbitlang/core#4844](https://github.com/moonbitlang/core/pull/4844),
complementing the framing work in [#4726](https://github.com/moonbitlang/core/pull/4726).
