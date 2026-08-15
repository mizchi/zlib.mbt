///| Zlib stored blocks implementation (no compression)

///|
/// Errors raised by zlib helpers.
///
/// `InvalidData` covers malformed inputs (bad headers, checksum mismatches,
/// truncated streams, invalid Huffman codes, etc.).
///
/// `OutputTooLarge` is raised when decompressed output would exceed the
/// configured `max_size`. Decompression APIs accept a `max_size~` labeled
/// argument; the default is `default_max_decompressed_size` (256 MiB).
pub(all) suberror ZlibError {
  InvalidData(String)
  OutputTooLarge(String)
} derive(Eq)

///|
pub impl Show for ZlibError with fn output(self, logger) {
  match self {
    InvalidData(msg) => logger.write_string("InvalidData(\{msg})")
    OutputTooLarge(msg) => logger.write_string("OutputTooLarge(\{msg})")
  }
}

///|
/// Default maximum decompressed output size (256 MiB).
///
/// All public decompression functions enforce this by default to prevent
/// "zip bomb" style DoS where a tiny crafted input decompresses to
/// gigabytes of memory. Override via the `max_size~` labeled argument.
pub let default_max_decompressed_size : Int = 256 * 1024 * 1024

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
/// Compute stored deflate size (no wrapper)
fn stored_deflate_len(len : Int) -> Int {
  if len == 0 {
    5
  } else {
    len + ((len - 1) / max_block_size + 1) * 5
  }
}

///|
/// Write deflate stored blocks into preallocated buffer.
/// Returns next offset after writing.
fn write_stored_deflate_blocks(
  out : FixedArray[Byte],
  start : Int,
  data : Bytes,
) -> Int {
  let len = data.length()
  let mut offset = start
  let mut pos = 0
  while pos < len {
    let remaining = len - pos
    let block_size = if remaining > max_block_size {
      max_block_size
    } else {
      remaining
    }
    let is_final = pos + block_size >= len
    out[offset] = if is_final { b'\x01' } else { b'\x00' }
    offset += 1
    out[offset] = (block_size & 0xff).to_byte()
    offset += 1
    out[offset] = ((block_size >> 8) & 0xff).to_byte()
    offset += 1
    let nlen = block_size ^ 0xffff
    out[offset] = (nlen & 0xff).to_byte()
    offset += 1
    out[offset] = ((nlen >> 8) & 0xff).to_byte()
    offset += 1
    for i = 0; i < block_size; i = i + 1 {
      out[offset + i] = data[pos + i]
    }
    offset += block_size
    pos += block_size
  }
  if len == 0 {
    out[offset] = b'\x01'
    out[offset + 1] = b'\x00'
    out[offset + 2] = b'\x00'
    out[offset + 3] = b'\xff'
    out[offset + 4] = b'\xff'
    offset += 5
  }
  offset
}

///|
/// Compress data using zlib stored blocks (no actual compression)
/// Format: CMF(0x78) + FLG(0x01) + blocks + Adler32
pub fn zlib_compress_stored(data : Bytes) -> Bytes {
  let deflate_len = stored_deflate_len(data.length())
  let total_len = 2 + deflate_len + 4
  let result : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')

  // Zlib header: CMF=0x78 (deflate, 32K window), FLG=0x01 (fastest)
  result[0] = b'\x78'
  result[1] = b'\x01'
  let offset = write_stored_deflate_blocks(result, 2, data)

  // Adler-32 checksum (big-endian)
  let checksum = adler32(data)
  write_u32_be(result, offset, checksum)
  Bytes::from_array(result)
}

///|
/// Decompress zlib stored blocks from the given offset.
/// Returns (decompressed_bytes, next_offset).
///
/// Output is capped at `max_size` bytes; if exceeded, raises
/// `OutputTooLarge` rather than allowing unbounded allocation.
pub fn zlib_decompress_stored_at(
  data : Bytes,
  start : Int,
  max_size? : Int = default_max_decompressed_size,
) -> (Bytes, Int) raise ZlibError {
  if max_size < 0 {
    raise ZlibError::InvalidData("max_size must be non-negative")
  }
  if start < 0 || start + 2 > data.length() {
    raise ZlibError::InvalidData("Zlib data too short")
  }

  // Verify zlib header. CM must be 8 (deflate); other CINFO values are valid.
  let cmf = data[start].to_int()
  let flg = data[start + 1].to_int()
  if (cmf & 0x0f) != 8 {
    raise ZlibError::InvalidData(
      "Unsupported compression method: \{cmf & 0x0f}",
    )
  }
  // FLG should make (CMF * 256 + FLG) % 31 == 0
  if (cmf * 256 + flg) % 31 != 0 {
    raise ZlibError::InvalidData("Invalid zlib FLG checksum")
  }
  // Reject preset dictionary (we do not support it)
  if ((flg >> 5) & 1) == 1 {
    raise ZlibError::InvalidData("Preset dictionary not supported")
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
    if result.length() + block_len > max_size {
      raise ZlibError::OutputTooLarge(
        "Decompressed output exceeds max_size=\{max_size}",
      )
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
pub fn zlib_decompress_stored(
  data : Bytes,
  max_size? : Int = default_max_decompressed_size,
) -> Bytes raise ZlibError {
  let (result, offset) = zlib_decompress_stored_at(data, 0, max_size~)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after zlib stream")
  }
  result
}

///|
/// Compress raw deflate stream using stored blocks (no compression).
pub fn deflate_compress_stored(data : Bytes) -> Bytes {
  let deflate_len = stored_deflate_len(data.length())
  let result : FixedArray[Byte] = FixedArray::make(deflate_len, b'\x00')
  let _ = write_stored_deflate_blocks(result, 0, data)
  Bytes::from_array(result)
}

///|
/// Compress gzip stream using stored deflate blocks (no compression).
pub fn gzip_compress_stored(data : Bytes) -> Bytes {
  let deflate_len = stored_deflate_len(data.length())
  let total_len = 10 + deflate_len + 8
  let out : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')
  out[0] = b'\x1f'
  out[1] = b'\x8b'
  out[2] = b'\x08'
  out[3] = b'\x00'
  out[4] = b'\x00'
  out[5] = b'\x00'
  out[6] = b'\x00'
  out[7] = b'\x00'
  out[8] = b'\x00'
  out[9] = b'\xff'
  let offset = write_stored_deflate_blocks(out, 10, data)
  let checksum = crc32(data)
  write_u32_le(out, offset, checksum)
  let size = Int::reinterpret_as_uint(data.length())
  write_u32_le(out, offset + 4, size)
  Bytes::from_array(out)
}

///|
fn read_u16_le(data : Bytes, start : Int) -> Int raise ZlibError {
  if start < 0 || start + 2 > data.length() {
    raise ZlibError::InvalidData("Unexpected end of data")
  }
  let b0 = data[start].to_int()
  let b1 = data[start + 1].to_int()
  b0 | (b1 << 8)
}

///|
fn read_u32_le(data : Bytes, start : Int) -> UInt raise ZlibError {
  if start < 0 || start + 4 > data.length() {
    raise ZlibError::InvalidData("Unexpected end of data")
  }
  let b0 = Int::reinterpret_as_uint(data[start].to_int())
  let b1 = Int::reinterpret_as_uint(data[start + 1].to_int())
  let b2 = Int::reinterpret_as_uint(data[start + 2].to_int())
  let b3 = Int::reinterpret_as_uint(data[start + 3].to_int())
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn write_u32_be(out : FixedArray[Byte], offset : Int, v : Int) -> Unit {
  out[offset] = ((v >> 24) & 0xff).to_byte()
  out[offset + 1] = ((v >> 16) & 0xff).to_byte()
  out[offset + 2] = ((v >> 8) & 0xff).to_byte()
  out[offset + 3] = (v & 0xff).to_byte()
}

///|
fn write_u32_le(out : FixedArray[Byte], offset : Int, v : UInt) -> Unit {
  let mask = Int::reinterpret_as_uint(255)
  out[offset] = (v & mask).to_byte()
  out[offset + 1] = ((v >> 8) & mask).to_byte()
  out[offset + 2] = ((v >> 16) & mask).to_byte()
  out[offset + 3] = ((v >> 24) & mask).to_byte()
}
