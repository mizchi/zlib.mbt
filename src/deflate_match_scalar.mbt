///|
/// Scalar LZ77 match length helper.
fn match_len(data : Bytes, candidate : Int, pos : Int, max_len : Int) -> Int {
  let mut l = min_match_len
  while l < max_len && data[candidate + l] == data[pos + l] {
    l += 1
  }
  l
}
