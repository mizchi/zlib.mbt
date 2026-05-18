# mizchi/zlib

Pure MoonBit zlib/deflate implementation. Supports:
- zlib streams (compress stored / full inflate)
- raw deflate (stored compress / full inflate)
- gzip (stored compress / full inflate)

```mbt check
///|
test "roundtrip stored" {
  let data : Bytes = "hello"
  let compressed = zlib_compress_stored(data)
  let decompressed = zlib_decompress_stored(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}
```

## Native target

`mizchi/zlib` itself is pure MoonBit on every target, including `native`.

If you want the system zlib backend explicitly, import `mizchi/zlib/native`:

```moonbit
import "mizchi/zlib/native" as @zlib_native

let compressed = @zlib_native.zlib_compress(data)
let decompressed = @zlib_native.zlib_decompress(compressed)
```

`mizchi/zlib/native` links `-lz` internally, so dependents do not need to add native linker flags themselves.

```bash
# Benchmarks
moon bench --target js
moon bench --target native
just bench-compare
```

## Benchmark (Rust flate2 / miniz_oxide baseline)

Measured on 2026-01-28 with `hyperfine --warmup 3` and the bundled 256KiB fixtures.
Commands are very short (<5ms), so shell overhead can skew results. wasm/wasm-gc uses
`moon run`, so the runtime/launcher overhead is included.

| Format | MoonBit native (mean) | Rust baseline (mean) | Relative | MoonBit wasm (mean) | MoonBit wasm-gc (mean) |
| --- | --- | --- | --- | --- | --- |
| zlib | 3.8 ms | 2.1 ms (flate2/miniz_oxide) | 1.8x slower | 31.8 ms | 22.9 ms |
| deflate | 3.7 ms | 2.1 ms (flate2/miniz_oxide) | 1.8x slower | 30.0 ms | 22.6 ms |
| gzip | 4.2 ms | 2.2 ms (flate2/miniz_oxide) | 1.9x slower | 30.7 ms | 27.1 ms |
