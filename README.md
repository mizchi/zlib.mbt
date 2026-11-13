# mizchi/zlib

> **Maintenance ended. Version 0.4.12 is the final release.**
> This repository is archived for existing users. New projects should use
> [moonbitlang/core](https://github.com/moonbitlang/core):
> [flate](https://mooncakes.io/docs/moonbitlang/core/compress/flate),
> [zlib](https://mooncakes.io/docs/moonbitlang/core/compress/zlib), and
> [gzip](https://mooncakes.io/docs/moonbitlang/core/compress/gzip).
> See the [migration guide](https://github.com/mizchi/zlib.mbt/blob/main/MIGRATION.md)
> for output limits, gzip boundary handling, and API differences.

Pure MoonBit zlib/deflate implementation.

## Features

- zlib streams (LZ77 compression / stored blocks / full inflate)
- raw deflate (LZ77 compression / stored blocks / full inflate)
- gzip (stored compress / full inflate)

## Quick Commands

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just bench     # run benchmarks
just bench-compare  # compare vs system zlib (hyperfine)
just bench-core native  # in-process comparison with MoonBit core (also js / wasm)
just test-update  # update snapshot tests
just info      # generate type definition files
```

## Native target

`mizchi/zlib` itself is pure MoonBit on every target, including `native`.

If you want the system zlib backend explicitly, import `mizchi/zlib/native`:

```moonbit
import "mizchi/zlib/native" as @zlib_native

let compressed = @zlib_native.zlib_compress(data)
let decompressed = @zlib_native.zlib_decompress(compressed)
```

The application using `mizchi/zlib/native` must link the system zlib. With the
current MoonBit toolchain, dependency link flags are not propagated to the final
executable. Add this to the application's `moon.pkg`:

```moon.pkg
options(
  link: { "native": { "cc-link-flags": "-lz" } },
)
```

This flag is needed only for the explicit system-libz backend. The pure MoonBit
`mizchi/zlib` package does not require it.

## Benchmark (Rust flate2 / miniz_oxide baseline)

Measured on 2026-01-28 with `hyperfine --warmup 3` and the bundled 256KiB fixtures.
Commands are very short (<5ms), so shell overhead can skew results. wasm/wasm-gc uses
`moon run`, so the runtime/launcher overhead is included.

| Format | MoonBit native (mean) | Rust baseline (mean) | Relative | MoonBit wasm (mean) | MoonBit wasm-gc (mean) |
| --- | --- | --- | --- | --- | --- |
| zlib | 3.8 ms | 2.1 ms (flate2/miniz_oxide) | 1.8x slower | 31.8 ms | 22.9 ms |
| deflate | 3.7 ms | 2.1 ms (flate2/miniz_oxide) | 1.8x slower | 30.0 ms | 22.6 ms |
| gzip | 4.2 ms | 2.2 ms (flate2/miniz_oxide) | 1.9x slower | 30.7 ms | 27.1 ms |

See [the MoonBit core comparison](benchmarks/CORE_COMPARISON.md) for current
native/JS/Wasm timings and compressed sizes. The submitted stored-bound optimization
is recorded in [the upstream PR report](benchmarks/CORE_STORED_BOUND_PR.md).

## Project Structure

```
zlib/
├── moon.mod
├── src/
│   ├── moon.pkg
│   ├── zlib.mbt
│   ├── inflate.mbt
│   ├── huffman.mbt
│   ├── adler32.mbt
│   └── zlib_test.mbt
└── justfile
```

## License

Apache-2.0
