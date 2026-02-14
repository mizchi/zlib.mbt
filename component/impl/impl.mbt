// User implementation for compress
// Bridges Array[Byte] <-> Bytes for @zlib package

///|
fn to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(arr[:])
}

///|
fn to_array(bytes : Bytes) -> Array[Byte] {
  bytes.to_array()
}

///|
/// Export: deflate-compress
pub fn deflate_compress(data : Array[Byte]) -> Array[Byte] {
  to_array(@zlib.deflate_compress(to_bytes(data)))
}

///|
/// Export: deflate-decompress
pub fn deflate_decompress(data : Array[Byte]) -> Result[Array[Byte], String] {
  try {
    Ok(to_array(@zlib.deflate_decompress(to_bytes(data))))
  } catch {
    e => Err(e.to_string())
  }
}

///|
/// Export: gzip-compress-stored
pub fn gzip_compress_stored(data : Array[Byte]) -> Array[Byte] {
  to_array(@zlib.gzip_compress_stored(to_bytes(data)))
}

///|
/// Export: gzip-decompress
pub fn gzip_decompress(data : Array[Byte]) -> Result[Array[Byte], String] {
  try {
    Ok(to_array(@zlib.gzip_decompress(to_bytes(data))))
  } catch {
    e => Err(e.to_string())
  }
}

///|
/// Export: zlib-compress
pub fn zlib_compress(data : Array[Byte]) -> Array[Byte] {
  to_array(@zlib.zlib_compress(to_bytes(data)))
}

///|
/// Export: zlib-decompress
pub fn zlib_decompress(data : Array[Byte]) -> Result[Array[Byte], String] {
  try {
    Ok(to_array(@zlib.zlib_decompress(to_bytes(data))))
  } catch {
    e => Err(e.to_string())
  }
}
