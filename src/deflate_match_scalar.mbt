///|
/// Scalar LZ77 match length helper.
fn match_len(
  data : Bytes,
  candidate : Int32,
  pos : Int32,
  max_len : Int32,
) -> Int32 {
  let mut l = min_match_len
  while l < max_len && data[candidate + l] == data[pos + l] {
    l += 1
  }
  l
}
