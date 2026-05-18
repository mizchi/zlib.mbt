///| JS/WASM target: pure MoonBit compress/decompress implementations

///|
/// Compress data using zlib (fixed Huffman).
pub fn zlib_compress(data : Bytes) -> Bytes {
  let deflated = deflate_compress(data)
  let total_len = 2 + deflated.length() + 4
  let result : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')
  result[0] = b'\x78'
  result[1] = b'\x01'
  for i = 0; i < deflated.length(); i = i + 1 {
    result[2 + i] = deflated[i]
  }
  let checksum = adler32(data)
  write_u32_be(result, 2 + deflated.length(), checksum)
  Bytes::from_array(result)
}

///|
/// Decompress a zlib stream (deflate with checksum) from the given offset.
/// Returns (decompressed_bytes, next_offset).
///
/// Output is capped at `max_size` bytes; if exceeded, raises
/// `OutputTooLarge`.
pub fn zlib_decompress_at(
  data : Bytes,
  start : Int,
  max_size? : Int = default_max_decompressed_size,
) -> (Bytes, Int) raise ZlibError {
  if start < 0 || start + 2 > data.length() {
    raise ZlibError::InvalidData("Zlib data too short")
  }
  let cmf = data[start].to_int()
  let flg = data[start + 1].to_int()
  if (cmf & 0x0f) != 8 {
    raise ZlibError::InvalidData("Unsupported compression method")
  }
  if (cmf * 256 + flg) % 31 != 0 {
    raise ZlibError::InvalidData("Invalid zlib FLG checksum")
  }
  let fdict = (flg >> 5) & 1
  if fdict == 1 {
    raise ZlibError::InvalidData("Preset dictionary not supported")
  }
  let deflate_start = start + 2
  let (result, offset) = inflate_deflate_stream(data, deflate_start, max_size)
  if offset + 4 > data.length() {
    raise ZlibError::InvalidData("Missing Adler-32 checksum")
  }
  let stored_checksum = (data[offset].to_int() << 24) |
    (data[offset + 1].to_int() << 16) |
    (data[offset + 2].to_int() << 8) |
    data[offset + 3].to_int()
  let computed_checksum = adler32(result)
  if stored_checksum != computed_checksum {
    raise ZlibError::InvalidData(
      "Adler-32 mismatch: stored=\{stored_checksum}, computed=\{computed_checksum}",
    )
  }
  (result, offset + 4)
}

///|
/// Decompress a full zlib stream.
pub fn zlib_decompress(
  data : Bytes,
  max_size? : Int = default_max_decompressed_size,
) -> Bytes raise ZlibError {
  let (result, offset) = zlib_decompress_at(data, 0, max_size~)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after zlib stream")
  }
  result
}

///|
/// Compress raw deflate stream (best compression).
pub fn deflate_compress(data : Bytes) -> Bytes {
  deflate_compress_best(data)
}

///|
/// Decompress raw deflate stream from the given offset.
pub fn deflate_decompress_at(
  data : Bytes,
  start : Int,
  max_size? : Int = default_max_decompressed_size,
) -> (Bytes, Int) raise ZlibError {
  inflate_deflate_stream(data, start, max_size)
}

///|
/// Decompress a full raw deflate stream.
pub fn deflate_decompress(
  data : Bytes,
  max_size? : Int = default_max_decompressed_size,
) -> Bytes raise ZlibError {
  let (result, offset) = deflate_decompress_at(data, 0, max_size~)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after deflate stream")
  }
  result
}

///|
/// Compress data using gzip (stored blocks).
pub fn gzip_compress(data : Bytes) -> Bytes {
  gzip_compress_stored(data)
}

///|
/// Decompress gzip stream from the given offset.
pub fn gzip_decompress_at(
  data : Bytes,
  start : Int,
  max_size? : Int = default_max_decompressed_size,
) -> (Bytes, Int) raise ZlibError {
  if start < 0 || start + 10 > data.length() {
    raise ZlibError::InvalidData("Gzip data too short")
  }
  if data[start] != b'\x1f' || data[start + 1] != b'\x8b' {
    raise ZlibError::InvalidData("Invalid gzip header")
  }
  if data[start + 2] != b'\x08' {
    raise ZlibError::InvalidData("Unsupported gzip compression method")
  }
  let flags = data[start + 3].to_int()
  let mut offset = start + 10
  if (flags & 0x04) != 0 {
    let xlen = read_u16_le(data, offset)
    offset += 2
    if offset + xlen > data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip extra field")
    }
    offset += xlen
  }
  if (flags & 0x08) != 0 {
    while offset < data.length() && data[offset] != b'\x00' {
      offset += 1
    }
    if offset >= data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip filename")
    }
    offset += 1
  }
  if (flags & 0x10) != 0 {
    while offset < data.length() && data[offset] != b'\x00' {
      offset += 1
    }
    if offset >= data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip comment")
    }
    offset += 1
  }
  if (flags & 0x02) != 0 {
    if offset + 2 > data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip header CRC")
    }
    offset += 2
  }
  let (result, end_offset) = inflate_deflate_stream(data, offset, max_size)
  if end_offset + 8 > data.length() {
    raise ZlibError::InvalidData("Missing gzip trailer")
  }
  let stored_crc = read_u32_le(data, end_offset)
  let stored_size = read_u32_le(data, end_offset + 4)
  let computed_crc = crc32(result)
  if stored_crc != computed_crc {
    raise ZlibError::InvalidData("CRC32 mismatch in gzip trailer")
  }
  let size = Int::reinterpret_as_uint(result.length())
  if stored_size != size {
    raise ZlibError::InvalidData("ISIZE mismatch in gzip trailer")
  }
  (result, end_offset + 8)
}

///|
/// Decompress a full gzip stream.
pub fn gzip_decompress(
  data : Bytes,
  max_size? : Int = default_max_decompressed_size,
) -> Bytes raise ZlibError {
  let (result, offset) = gzip_decompress_at(data, 0, max_size~)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after gzip stream")
  }
  result
}
