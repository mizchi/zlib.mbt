// Scalar slicing-by-8 inner loop — non-wasm targets.

///|
/// Slicing-by-8 auxiliary tables. `crc32_table_8[k][i]` is the CRC32 of a
/// single byte `i` shifted by `(k+1) * 8` positions through the
/// polynomial. The 8-byte fast path XORs eight pre-shifted table lookups
/// instead of doing eight serial dependent steps.
let crc32_table_8 : FixedArray[FixedArray[UInt]] = {
  let tables : FixedArray[FixedArray[UInt]] = FixedArray::makei(8, fn(_) {
    FixedArray::make(256, Int::reinterpret_as_uint(0))
  })
  tables[0] = crc32_table
  for k in 1..<8 {
    let prev = tables[k - 1]
    let cur = FixedArray::make(256, Int::reinterpret_as_uint(0))
    for i in 0..<256 {
      let v = prev[i]
      cur[i] = (v >> 8) ^ crc32_table[UInt::reinterpret_as_int(v & 0xFFU)]
    }
    tables[k] = cur
  }
  tables
}

///|
fn crc32_bulk_impl(data : Bytes, bulk_end : Int, crc_in : Int) -> Int {
  let mut crc = crc_in.reinterpret_as_uint()
  let t0 = crc32_table_8[0]
  let t1 = crc32_table_8[1]
  let t2 = crc32_table_8[2]
  let t3 = crc32_table_8[3]
  let t4 = crc32_table_8[4]
  let t5 = crc32_table_8[5]
  let t6 = crc32_table_8[6]
  let t7 = crc32_table_8[7]
  let mut i = 0
  while i < bulk_end {
    let b0 = Int::reinterpret_as_uint(data[i].to_int())
    let b1 = Int::reinterpret_as_uint(data[i + 1].to_int())
    let b2 = Int::reinterpret_as_uint(data[i + 2].to_int())
    let b3 = Int::reinterpret_as_uint(data[i + 3].to_int())
    let b4 = Int::reinterpret_as_uint(data[i + 4].to_int())
    let b5 = Int::reinterpret_as_uint(data[i + 5].to_int())
    let b6 = Int::reinterpret_as_uint(data[i + 6].to_int())
    let b7 = Int::reinterpret_as_uint(data[i + 7].to_int())
    let a = crc ^ (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
    let b = b4 | (b5 << 8) | (b6 << 16) | (b7 << 24)
    crc = t7[UInt::reinterpret_as_int(a & 0xFFU)] ^
      t6[UInt::reinterpret_as_int((a >> 8) & 0xFFU)] ^
      t5[UInt::reinterpret_as_int((a >> 16) & 0xFFU)] ^
      t4[UInt::reinterpret_as_int((a >> 24) & 0xFFU)] ^
      t3[UInt::reinterpret_as_int(b & 0xFFU)] ^
      t2[UInt::reinterpret_as_int((b >> 8) & 0xFFU)] ^
      t1[UInt::reinterpret_as_int((b >> 16) & 0xFFU)] ^
      t0[UInt::reinterpret_as_int((b >> 24) & 0xFFU)]
    i = i + 8
  }
  crc.reinterpret_as_int()
}
