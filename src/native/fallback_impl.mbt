///|
pub type ZlibError = @zlib.ZlibError

///|
pub fn zlib_compress(data : Bytes) -> Bytes {
  @zlib.zlib_compress(data)
}

///|
pub fn zlib_decompress(data : Bytes) -> Bytes raise ZlibError {
  @zlib.zlib_decompress(data)
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
  @zlib.deflate_compress(data)
}

///|
pub fn deflate_decompress(data : Bytes) -> Bytes raise ZlibError {
  @zlib.deflate_decompress(data)
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
  @zlib.gzip_compress(data)
}

///|
pub fn gzip_decompress(data : Bytes) -> Bytes raise ZlibError {
  @zlib.gzip_decompress(data)
}

///|
pub fn gzip_decompress_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  @zlib.gzip_decompress_at(data, start)
}
