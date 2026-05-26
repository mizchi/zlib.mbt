///| CRC32 implementation for gzip

///|
let crc32_poly : UInt = (Int::reinterpret_as_uint(237) << 24) |
  (Int::reinterpret_as_uint(184) << 16) |
  (Int::reinterpret_as_uint(131) << 8) |
  Int::reinterpret_as_uint(32)

///|
fn build_crc32_table() -> FixedArray[UInt] {
  FixedArray::makei(256, fn(i) {
    let mut c = i.reinterpret_as_uint()
    for _ in 0..<8 {
      if (c & Int::reinterpret_as_uint(1)) == Int::reinterpret_as_uint(1) {
        c = (c >> 1) ^ crc32_poly
      } else {
        c = c >> 1
      }
    }
    c
  })
}

///|
let crc32_table : FixedArray[UInt] = build_crc32_table()

///|
/// Reflected CRC-32 (zlib/gzip polynomial 0xEDB88320). Slicing-by-8 bulk
/// path delegates to a target-conditional inner loop (`crc32_bulk_impl`),
/// then finishes the trailing 0–7 bytes with the standard byte table.
///
/// Inner loop dispatch:
///   * wasm     — `crc32_simd.mbt`, inline-WAT with direct `i32.load`s
///                of the input bytes and 8 parallel `i32.load`s from a
///                flattened slicing-by-8 table.
///   * other    — `crc32_scalar.mbt`, pure-MoonBit slicing-by-8.
pub fn crc32(data : Bytes) -> UInt {
  let mut crc : UInt = Int::reinterpret_as_uint(-1)
  let len = data.length()
  let bulk_end = len & -8
  if bulk_end > 0 {
    crc = Int::reinterpret_as_uint(
      crc32_bulk_impl(data, bulk_end, crc.reinterpret_as_int()),
    )
  }
  let mut i = bulk_end
  while i < len {
    let idx = UInt::reinterpret_as_int(
      (crc ^ Int::reinterpret_as_uint(data[i].to_int())) & 0xFFU,
    )
    crc = (crc >> 8) ^ crc32_table[idx]
    i = i + 1
  }
  crc ^ Int::reinterpret_as_uint(-1)
}

///|
pub fn crc32_fixed(data : FixedArray[Byte]) -> UInt {
  crc32(Bytes::from_array(data))
}
