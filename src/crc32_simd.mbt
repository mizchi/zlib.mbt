// Inline-WAT slicing-by-8 inner loop — wasm target only.
//
// Reads input bytes via direct `i32.load` (4 bytes LE per fetch — saves
// 4 MoonBit `Bytes[i]` calls each with their UInt conversion overhead).
// The 8 table lookups go through a single flattened i32 array
// (`crc32_table_flat` from crc32.mbt) instead of a nested
// `FixedArray[FixedArray[UInt]]` — saves the per-lookup outer-array
// dereference.
//
// Bytes-direct inline-WAT works on the `wasm` target because the FFI
// passes Bytes as a linear-memory pointer. wasm-gc treats Bytes as a GC
// ref and rejects it, so wasm-gc/native/js fall through to the scalar
// path in crc32_scalar.mbt.

///|
/// Flattened slicing-by-8 table: 8 sub-tables × 256 entries laid out as a
/// single FixedArray[Int] of length 2048. The inline-WAT inner loop
/// indexes via byte offset `(k * 256 + i) * 4` into linear memory.
/// `Int` (not `UInt`) because inline-WAT only has the i32 ABI.
let crc32_table_flat : FixedArray[Int] = {
  let arr = FixedArray::make(2048, 0)
  for i in 0..<256 {
    let mut v = i.reinterpret_as_uint()
    for _ in 0..<8 {
      if (v & 1U) != 0U {
        v = (v >> 1) ^ crc32_poly
      } else {
        v = v >> 1
      }
    }
    arr[i] = v.reinterpret_as_int()
  }
  for k in 1..<8 {
    for i in 0..<256 {
      let prev = arr[(k - 1) * 256 + i].reinterpret_as_uint()
      arr[k * 256 + i] = ((prev >> 8) ^
        arr[(prev & 0xFFU).reinterpret_as_int()].reinterpret_as_uint()).reinterpret_as_int()
    }
  }
  arr
}

///|
fn crc32_bulk_impl(data : Bytes, bulk_end : Int, crc_in : Int) -> Int {
  crc32_simd_chunks(data, bulk_end, crc32_table_flat, crc_in)
}

///|
/// Inline-WAT inner loop. Params: 0 = data ptr, 1 = end, 2 =
/// table_flat ptr, 3 = crc_in. Returns updated crc.
/// Locals: 4 = i, 5 = crc, 6 = a, 7 = b.
#borrow(data, table_flat)
fn crc32_simd_chunks(
  data : Bytes,
  end : Int,
  table_flat : FixedArray[Int],
  crc_in : Int,
) -> Int =
  #|(func (param i32) (param i32) (param i32) (param i32) (result i32) (local i32) (local i32) (local i32) (local i32) local.get 3 local.set 5 block loop local.get 4 local.get 1 i32.ge_s br_if 1 local.get 0 local.get 4 i32.add i32.load local.get 5 i32.xor local.set 6 local.get 0 local.get 4 i32.add i32.const 4 i32.add i32.load local.set 7 local.get 2 local.get 6 i32.const 255 i32.and i32.const 2 i32.shl i32.add i32.const 7168 i32.add i32.load local.get 2 local.get 6 i32.const 8 i32.shr_u i32.const 255 i32.and i32.const 2 i32.shl i32.add i32.const 6144 i32.add i32.load i32.xor local.get 2 local.get 6 i32.const 16 i32.shr_u i32.const 255 i32.and i32.const 2 i32.shl i32.add i32.const 5120 i32.add i32.load i32.xor local.get 2 local.get 6 i32.const 24 i32.shr_u i32.const 2 i32.shl i32.add i32.const 4096 i32.add i32.load i32.xor local.get 2 local.get 7 i32.const 255 i32.and i32.const 2 i32.shl i32.add i32.const 3072 i32.add i32.load i32.xor local.get 2 local.get 7 i32.const 8 i32.shr_u i32.const 255 i32.and i32.const 2 i32.shl i32.add i32.const 2048 i32.add i32.load i32.xor local.get 2 local.get 7 i32.const 16 i32.shr_u i32.const 255 i32.and i32.const 2 i32.shl i32.add i32.const 1024 i32.add i32.load i32.xor local.get 2 local.get 7 i32.const 24 i32.shr_u i32.const 2 i32.shl i32.add i32.load i32.xor local.set 5 local.get 4 i32.const 8 i32.add local.set 4 br 0 end end local.get 5)
