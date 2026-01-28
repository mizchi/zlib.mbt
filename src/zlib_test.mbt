///|
/// Tests for zlib stored blocks implementation
test "adler32 empty" {
  let result = adler32(Bytes::from_array([]))
  inspect(result, content="1")
}

///|
test "adler32 simple" {
  // "abc" should produce known value
  let data = Bytes::from_array([b'a', b'b', b'c'])
  let result = adler32(data)
  // s1 = 1 + 97 + 98 + 99 = 295
  // s2 = 0 + (1+97) + (1+97+98) + (1+97+98+99) = 98 + 196 + 295 = 589
  // result = (589 << 16) | 295 = 38600999
  inspect(result, content="38600999")
}

///|
test "zlib round trip empty" {
  let data = Bytes::from_array([])
  let compressed = zlib_compress_stored(data)
  let decompressed = zlib_decompress_stored(compressed)
  inspect(decompressed.length(), content="0")
}

///|
test "zlib round trip simple" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = zlib_compress_stored(data)
  let decompressed = zlib_decompress_stored(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "zlib round trip larger" {
  // Test with data larger than comfort but smaller than block limit
  let data : Array[Byte] = []
  for i = 0; i < 1000; i = i + 1 {
    data.push((i % 256).to_byte())
  }
  let bytes = Bytes::from_array(
    FixedArray::makei(data.length(), fn(i) { data[i] }),
  )
  let compressed = zlib_compress_stored(bytes)
  let decompressed = zlib_decompress_stored(compressed)
  inspect(decompressed.length(), content="1000")

  // Verify content
  for i = 0; i < 1000; i = i + 1 {
    assert_eq(decompressed[i], (i % 256).to_byte())
  }
}

///|
test "zlib header format" {
  let data = Bytes::from_array([b'x'])
  let compressed = zlib_compress_stored(data)

  // Check zlib header
  inspect(compressed[0], content="b'\\x78'") // CMF
  inspect(compressed[1], content="b'\\x01'") // FLG

  // Check BFINAL=1 (stored block, final)
  inspect(compressed[2], content="b'\\x01'")

  // Check LEN=1 (little-endian)
  inspect(compressed[3], content="b'\\x01'")
  inspect(compressed[4], content="b'\\x00'")

  // Check NLEN=0xfffe
  inspect(compressed[5], content="b'\\xFE'")
  inspect(compressed[6], content="b'\\xFF'")

  // Check data
  inspect(compressed[7], content="b'\\x78'") // 'x'
}

///|
test "zlib decompress at offset" {
  let payload = Bytes::from_array([b'a', b'b'])
  let compressed = zlib_compress_stored(payload)
  let bytes : Array[Byte] = []
  bytes.push(b'X')
  bytes.push(b'Y')
  for b in compressed {
    bytes.push(b)
  }
  bytes.push(b'Z')
  let data = Bytes::from_array(
    FixedArray::makei(bytes.length(), fn(i) { bytes[i] }),
  )
  let (out, next_offset) = zlib_decompress_stored_at(data, 2)
  assert_true(out.length() == payload.length())
  for i = 0; i < payload.length(); i = i + 1 {
    assert_true(out[i] == payload[i])
  }
  assert_true(next_offset == 2 + compressed.length())
}

///|
test "zlib decompress deflate" {
  // zlib.deflateSync(Buffer.from("hello")).toString("hex")
  let hex = "789ccb48cdc9c90700062c0215"
  let bytes : Array[Byte] = []
  let chars = hex.to_array()
  for i in 0..<(hex.length() / 2) {
    let hi = hex_char_to_int(chars[i * 2])
    let lo = hex_char_to_int(chars[i * 2 + 1])
    bytes.push(((hi << 4) | lo).to_byte())
  }
  let compressed = Bytes::from_array(
    FixedArray::makei(bytes.length(), fn(i) { bytes[i] }),
  )
  let decompressed = zlib_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
fn hex_char_to_int(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    0
  }
}
