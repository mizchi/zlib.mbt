// Scalar Adler-32 — used on every target except wasm.

///|
fn adler32_impl(data : Bytes) -> Int {
  let mut s1 : UInt = Int::reinterpret_as_uint(1)
  let mut s2 : UInt = Int::reinterpret_as_uint(0)
  let mut i = 0
  let len = data.length()
  while i < len {
    let remaining = len - i
    let chunk = if remaining > adler_nmax { adler_nmax } else { remaining }
    for j in 0..<chunk {
      let byte_val = data[i + j].to_uint()
      s1 += byte_val
      s2 += s1
    }
    s1 = s1 % adler_mod
    s2 = s2 % adler_mod
    i += chunk
  }
  UInt::reinterpret_as_int((s2 << 16) | s1)
}

///|
fn adler32_fixed_impl(data : FixedArray[Byte]) -> Int {
  let mut s1 : UInt = Int::reinterpret_as_uint(1)
  let mut s2 : UInt = Int::reinterpret_as_uint(0)
  let len = data.length()
  let mut i = 0
  while i < len {
    let remaining = len - i
    let chunk = if remaining > adler_nmax { adler_nmax } else { remaining }
    for j in 0..<chunk {
      let byte_val = data[i + j].to_uint()
      s1 += byte_val
      s2 += s1
    }
    s1 = s1 % adler_mod
    s2 = s2 % adler_mod
    i += chunk
  }
  UInt::reinterpret_as_int((s2 << 16) | s1)
}
