///|
/// Adler-32 checksum implementation for zlib
let adler_mod : Int = 65521

///|
/// Compute Adler-32 checksum
pub fn adler32(data : Bytes) -> Int {
  let mut s1 = 1
  let mut s2 = 0
  for b in data {
    s1 = (s1 + b.to_int()) % adler_mod
    s2 = (s2 + s1) % adler_mod
  }
  (s2 << 16) | s1
}

///|
/// Compute Adler-32 checksum from FixedArray
pub fn adler32_fixed(data : FixedArray[Byte]) -> Int {
  let mut s1 = 1
  let mut s2 = 0
  for b in data {
    s1 = (s1 + b.to_int()) % adler_mod
    s2 = (s2 + s1) % adler_mod
  }
  (s2 << 16) | s1
}
