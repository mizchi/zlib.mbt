///|
test "native zlib roundtrip fixed" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = zlib_compress(data)
  let decompressed = zlib_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "native deflate roundtrip fixed" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = deflate_compress(data)
  let decompressed = deflate_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "native gzip roundtrip fixed" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = gzip_compress(data)
  let decompressed = gzip_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}
