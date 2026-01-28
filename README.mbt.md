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

```bash
# Benchmarks
moon bench --target js
moon bench --target native
```
