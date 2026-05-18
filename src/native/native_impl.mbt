///|
pub type ZlibError = @zlib.ZlibError

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
    raise @zlib.ZlibError::InvalidData("native zlib error: \{result}")
  }
  raise @zlib.ZlibError::InvalidData("native zlib: output buffer too small")
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
  @zlib.zlib_decompress_at(data, start)
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
  @zlib.deflate_decompress_at(data, start)
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
  @zlib.gzip_decompress_at(data, start)
}
