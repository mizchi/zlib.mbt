///|
/// Wasm SIMD LZ77 match length helper.
///
/// The caller has already checked the first three bytes. This compares the
/// remaining bytes 16 lanes at a time, then falls back to a scalar tail.
#borrow(data)
fn match_len(data : Bytes, candidate : Int, pos : Int, max_len : Int) -> Int =
  #|(func (param i32) (param i32) (param i32) (param i32) (result i32) (local i32) (local i32) i32.const 3 local.set 4 block loop local.get 4 i32.const 16 i32.add local.get 3 i32.gt_s br_if 1 local.get 0 local.get 1 i32.add local.get 4 i32.add v128.load local.get 0 local.get 2 i32.add local.get 4 i32.add v128.load i8x16.eq i8x16.bitmask local.tee 5 i32.const 65535 i32.ne if local.get 4 local.get 5 i32.const 65535 i32.xor i32.ctz i32.add return end local.get 4 i32.const 16 i32.add local.set 4 br 0 end end block loop local.get 4 local.get 3 i32.ge_s br_if 1 local.get 0 local.get 1 i32.add local.get 4 i32.add i32.load8_u local.get 0 local.get 2 i32.add local.get 4 i32.add i32.load8_u i32.ne if local.get 4 return end local.get 4 i32.const 1 i32.add local.set 4 br 0 end end local.get 4)
