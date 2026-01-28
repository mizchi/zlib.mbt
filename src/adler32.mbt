///|
/// Adler-32 checksum implementation for zlib
let adler_mod : Int = 65521

///|
let adler_nmax : Int = 5552

///|
fn adler32_bytes(data : Bytes) -> Int {
  let mut s1 = 1
  let mut s2 = 0
  let mut i = 0
  let len = data.length()
  while i < len {
    let remaining = len - i
    let chunk = if remaining > adler_nmax { adler_nmax } else { remaining }
    for j in 0..<chunk {
      s1 += data[i + j].to_int()
      s2 += s1
    }
    s1 %= adler_mod
    s2 %= adler_mod
    i += chunk
  }
  (s2 << 16) | s1
}

///|
/// Compute Adler-32 checksum
pub fn adler32(data : Bytes) -> Int {
  adler32_bytes(data)
}

///|
/// Compute Adler-32 checksum from FixedArray
pub fn adler32_fixed(data : FixedArray[Byte]) -> Int {
  let mut s1 = 1
  let mut s2 = 0
  let len = data.length()
  let mut i = 0
  while i < len {
    let remaining = len - i
    let chunk = if remaining > adler_nmax { adler_nmax } else { remaining }
    for j in 0..<chunk {
      s1 += data[i + j].to_int()
      s2 += s1
    }
    s1 %= adler_mod
    s2 %= adler_mod
    i += chunk
  }
  (s2 << 16) | s1
}
