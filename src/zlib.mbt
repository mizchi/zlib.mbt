///| Zlib stored blocks implementation (no compression)

///|
/// Errors raised by zlib helpers
pub(all) suberror ZlibError {
  InvalidData(String)
} derive(Show, Eq)

///| Git servers accept uncompressed deflate data

///|
/// Maximum size for a single stored block
let max_block_size : Int = 65535

///|
/// Helper to convert Array[Byte] to Bytes
fn zlib_array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), fn(i) { arr[i] }))
}

///|
/// Compress data using zlib stored blocks (no actual compression)
/// Format: CMF(0x78) + FLG(0x01) + blocks + Adler32
pub fn zlib_compress_stored(data : Bytes) -> Bytes {
  let result : Array[Byte] = []

  // Zlib header: CMF=0x78 (deflate, 32K window), FLG=0x01 (fastest)
  result.push(b'\x78')
  result.push(b'\x01')

  // Split into 64KB blocks
  let len = data.length()
  let mut offset = 0
  while offset < len {
    let remaining = len - offset
    let block_size = if remaining > max_block_size {
      max_block_size
    } else {
      remaining
    }
    let is_final = offset + block_size >= len

    // Block header: BFINAL(1) + BTYPE(00=stored)
    if is_final {
      result.push(b'\x01') // BFINAL=1, BTYPE=00
    } else {
      result.push(b'\x00') // BFINAL=0, BTYPE=00
    }

    // LEN (little-endian)
    result.push((block_size & 0xff).to_byte())
    result.push(((block_size >> 8) & 0xff).to_byte())

    // NLEN (one's complement of LEN)
    let nlen = block_size ^ 0xffff
    result.push((nlen & 0xff).to_byte())
    result.push(((nlen >> 8) & 0xff).to_byte())

    // Raw data
    for i = 0; i < block_size; i = i + 1 {
      result.push(data[offset + i])
    }
    offset += block_size
  }

  // Handle empty data case
  if len == 0 {
    result.push(b'\x01') // BFINAL=1, BTYPE=00
    result.push(b'\x00') // LEN=0
    result.push(b'\x00')
    result.push(b'\xff') // NLEN=0xffff
    result.push(b'\xff')
  }

  // Adler-32 checksum (big-endian)
  let checksum = adler32(data)
  result.push(((checksum >> 24) & 0xff).to_byte())
  result.push(((checksum >> 16) & 0xff).to_byte())
  result.push(((checksum >> 8) & 0xff).to_byte())
  result.push((checksum & 0xff).to_byte())
  zlib_array_to_bytes(result)
}

///|
/// Decompress zlib stored blocks from the given offset.
/// Returns (decompressed_bytes, next_offset).
pub fn zlib_decompress_stored_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  if start < 0 || start + 2 > data.length() {
    raise ZlibError::InvalidData("Zlib data too short")
  }

  // Verify zlib header
  let cmf = data[start].to_int()
  let flg = data[start + 1].to_int()
  if cmf != 0x78 {
    raise ZlibError::InvalidData("Invalid zlib CMF: \{cmf}")
  }
  // FLG should make (CMF * 256 + FLG) % 31 == 0
  if (cmf * 256 + flg) % 31 != 0 {
    raise ZlibError::InvalidData("Invalid zlib FLG checksum")
  }
  let result : Array[Byte] = []
  let mut offset = start + 2

  // Read blocks
  while true {
    if offset >= data.length() {
      raise ZlibError::InvalidData("Unexpected end of zlib data")
    }
    if offset + 5 > data.length() {
      raise ZlibError::InvalidData("Unexpected end of zlib block header")
    }
    let header = data[offset].to_int()
    offset += 1
    let bfinal = header & 1
    let btype = (header >> 1) & 3
    if btype != 0 {
      raise ZlibError::InvalidData(
        "Only stored blocks supported, got BTYPE=\{btype}",
      )
    }

    // Read LEN (little-endian)
    let len_lo = data[offset].to_int()
    let len_hi = data[offset + 1].to_int()
    let block_len = len_lo | (len_hi << 8)
    offset += 2

    // Read NLEN and verify
    let nlen_lo = data[offset].to_int()
    let nlen_hi = data[offset + 1].to_int()
    let nlen = nlen_lo | (nlen_hi << 8)
    offset += 2
    if (block_len ^ nlen) != 0xffff {
      raise ZlibError::InvalidData("Invalid stored block length")
    }
    if offset + block_len > data.length() {
      raise ZlibError::InvalidData("Unexpected end of stored block data")
    }
    // Copy raw data
    for i = 0; i < block_len; i = i + 1 {
      result.push(data[offset])
      offset += 1
    }
    if bfinal == 1 {
      break
    }
  }

  // Verify Adler-32 (big-endian)
  if offset + 4 > data.length() {
    raise ZlibError::InvalidData("Missing Adler-32 checksum")
  }
  let stored_checksum = (data[offset].to_int() << 24) |
    (data[offset + 1].to_int() << 16) |
    (data[offset + 2].to_int() << 8) |
    data[offset + 3].to_int()
  offset += 4
  let result_bytes = zlib_array_to_bytes(result)
  let computed_checksum = adler32(result_bytes)
  if stored_checksum != computed_checksum {
    raise ZlibError::InvalidData(
      "Adler-32 mismatch: stored=\{stored_checksum}, computed=\{computed_checksum}",
    )
  }
  (result_bytes, offset)
}

///|
/// Decompress zlib stored blocks (single stream)
pub fn zlib_decompress_stored(data : Bytes) -> Bytes raise ZlibError {
  let (result, offset) = zlib_decompress_stored_at(data, 0)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after zlib stream")
  }
  result
}

///|
/// Decompress a zlib stream (deflate with checksum) from the given offset.
/// Returns (decompressed_bytes, next_offset).
pub fn zlib_decompress_at(
  data : Bytes,
  start : Int,
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
  let (result, offset) = inflate_deflate_stream(data, deflate_start)
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
pub fn zlib_decompress(data : Bytes) -> Bytes raise ZlibError {
  let (result, offset) = zlib_decompress_at(data, 0)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after zlib stream")
  }
  result
}
