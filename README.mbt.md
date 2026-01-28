# mizchi/zlib

Pure MoonBit zlib/deflate implementation. Currently supports stored blocks and inflate helpers.

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
