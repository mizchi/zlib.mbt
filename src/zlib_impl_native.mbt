///| Native target: C FFI to system zlib

///|
#borrow(input, output)
extern "C" fn zlib_compress_ffi(
  input : Bytes,
  input_len : Int,
  output : Bytes,
  max_output_len : Int,
) -> Int = "mizchi_zlib_native_compress"

///|
#borrow(input, output)
extern "C" fn zlib_decompress_ffi(
  input : Bytes,
  input_len : Int,
  output : Bytes,
  max_output_len : Int,
) -> Int = "mizchi_zlib_native_decompress"

///|
#borrow(input, output)
extern "C" fn deflate_compress_ffi(
  input : Bytes,
  input_len : Int,
  output : Bytes,
  max_output_len : Int,
) -> Int = "mizchi_zlib_native_deflate_compress"

///|
#borrow(input, output)
extern "C" fn deflate_decompress_ffi(
  input : Bytes,
  input_len : Int,
  output : Bytes,
  max_output_len : Int,
) -> Int = "mizchi_zlib_native_deflate_decompress"

///|
#borrow(input, output)
extern "C" fn gzip_compress_ffi(
  input : Bytes,
  input_len : Int,
  output : Bytes,
  max_output_len : Int,
) -> Int = "mizchi_zlib_native_gzip_compress"

///|
#borrow(input, output)
extern "C" fn gzip_decompress_ffi(
  input : Bytes,
  input_len : Int,
  output : Bytes,
  max_output_len : Int,
) -> Int = "mizchi_zlib_native_gzip_decompress"

///|
fn call_ffi(
  data : Bytes,
  max_ratio : Int,
  ffi : (Bytes, Int, Bytes, Int) -> Int,
) -> Bytes raise ZlibError {
  let input_len = data.length()
  let initial = input_len * max_ratio
  let mut max_out = if initial < 1024 { 1024 } else { initial }
  for _ in 0..<16 {
    let output = Bytes::make(max_out, b'\x00')
    let result = ffi(data, input_len, output, max_out)
    if result >= 0 {
      return Bytes::makei(result, fn(i) { output[i] })
    }
    if result == -2 {
      max_out = max_out * 2
      continue
    }
    raise ZlibError::InvalidData("native zlib error: \{result}")
  }
  raise ZlibError::InvalidData("native zlib: output buffer too small")
}

///|
pub fn zlib_compress(data : Bytes) -> Bytes {
  call_ffi(data, 2, zlib_compress_ffi) catch {
    _ => abort("zlib_compress failed")
  }
}

///|
pub fn zlib_decompress(data : Bytes) -> Bytes raise ZlibError {
  call_ffi(data, 8, zlib_decompress_ffi)
}

///|
pub fn zlib_decompress_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  // For offset-based decompression, use pure MoonBit inflate
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
pub fn deflate_compress(data : Bytes) -> Bytes {
  call_ffi(data, 2, deflate_compress_ffi) catch {
    _ => abort("deflate_compress failed")
  }
}

///|
pub fn deflate_decompress(data : Bytes) -> Bytes raise ZlibError {
  call_ffi(data, 8, deflate_decompress_ffi)
}

///|
pub fn deflate_decompress_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  inflate_deflate_stream(data, start)
}

///|
pub fn gzip_compress(data : Bytes) -> Bytes {
  call_ffi(data, 2, gzip_compress_ffi) catch {
    _ => abort("gzip_compress failed")
  }
}

///|
pub fn gzip_decompress(data : Bytes) -> Bytes raise ZlibError {
  call_ffi(data, 8, gzip_decompress_ffi)
}

///|
pub fn gzip_decompress_at(
  data : Bytes,
  start : Int,
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
  let (result, end_offset) = inflate_deflate_stream(data, offset)
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
