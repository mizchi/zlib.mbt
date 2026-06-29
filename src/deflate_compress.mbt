///| Deflate compression (fixed Huffman + LZ77)

///|
let deflate_length_base : FixedArray[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let deflate_length_extra : FixedArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let deflate_dist_base : FixedArray[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let deflate_dist_extra : FixedArray[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
let window_size : Int = 32768

///|
let max_match_len : Int = 258

///|
let min_match_len : Int = 3

///|
let hash_size : Int = 1 << 15

///|
let max_chain : Int = 64

///|
fn pack_token_lit(sym : Int) -> Int {
  sym << 1
}

///|
fn pack_token_match(len : Int, dist : Int) -> Int {
  (((dist << 9) | len) << 1) | 1
}

///|
fn token_is_match(token : Int) -> Bool {
  (token & 1) != 0
}

///|
fn token_lit_sym(token : Int) -> Int {
  token >> 1
}

///|
fn token_match_len(token : Int) -> Int {
  (token >> 1) & 0x1ff
}

///|
fn token_match_dist(token : Int) -> Int {
  token >> 10
}

///|
#valtype
priv struct HuffNode {
  freq : Int
  left : Int
  right : Int
  sym : Int
}

///|
fn deflate_reverse_bits(code : Int, len : Int) -> Int {
  let mut v = code
  let mut out = 0
  let mut n = len
  while n > 0 {
    out = (out << 1) | (v & 1)
    v = v >> 1
    n -= 1
  }
  out
}

///|
fn pack_code_len(code : Int, len : Int) -> Int {
  (len << 16) | code
}

///|
fn packed_code(packed : Int) -> Int {
  packed & 0xffff
}

///|
fn packed_code_len(packed : Int) -> Int {
  packed >> 16
}

///|
fn write_packed_code(writer : BitWriter, packed : Int) -> Unit {
  writer.write_bits(packed_code(packed), packed_code_len(packed))
}

///|
fn pack_symbol_info(sym : Int, extra_bits : Int, extra_val : Int) -> Int {
  sym | (extra_bits << 9) | (extra_val << 13)
}

///|
fn packed_info_sym(packed : Int) -> Int {
  packed & 0x1ff
}

///|
fn packed_info_extra_bits(packed : Int) -> Int {
  (packed >> 9) & 0xf
}

///|
fn packed_info_extra_val(packed : Int) -> Int {
  packed >> 13
}

///|
fn fixed_lit_code(sym : Int) -> Int {
  if sym <= 143 {
    let code = sym + 0x30
    pack_code_len(deflate_reverse_bits(code, 8), 8)
  } else if sym <= 255 {
    let code = sym - 144 + 0x190
    pack_code_len(deflate_reverse_bits(code, 9), 9)
  } else if sym <= 279 {
    let code = sym - 256
    pack_code_len(deflate_reverse_bits(code, 7), 7)
  } else {
    let code = sym - 280 + 0xC0
    pack_code_len(deflate_reverse_bits(code, 8), 8)
  }
}

///|
fn fixed_dist_code(sym : Int) -> Int {
  pack_code_len(deflate_reverse_bits(sym, 5), 5)
}

///|
fn length_code_info(len : Int) -> Int {
  for i in 0..<deflate_length_base.length() {
    let base = deflate_length_base[i]
    let extra = deflate_length_extra[i]
    let max_len = base + ((1 << extra) - 1)
    if len <= max_len {
      return pack_symbol_info(257 + i, extra, len - base)
    }
  }
  pack_symbol_info(285, 0, 0)
}

///|
fn dist_code_info(dist : Int) -> Int {
  for i in 0..<deflate_dist_base.length() {
    let base = deflate_dist_base[i]
    let extra = deflate_dist_extra[i]
    let max_dist = base + ((1 << extra) - 1)
    if dist <= max_dist {
      return pack_symbol_info(i, extra, dist - base)
    }
  }
  pack_symbol_info(29, 13, dist - deflate_dist_base[29])
}

///|
fn hash3(data : Bytes, pos : Int) -> Int {
  let b0 = data[pos].to_int()
  let b1 = data[pos + 1].to_int()
  let b2 = data[pos + 2].to_int()
  ((b0 << 8) ^ (b1 << 4) ^ b2) & (hash_size - 1)
}

///|
fn write_literal(writer : BitWriter, sym : Int) -> Unit {
  write_packed_code(writer, fixed_lit_code(sym))
}

///|
fn write_match(writer : BitWriter, length : Int, distance : Int) -> Unit {
  let len_info = length_code_info(length)
  let len_extra_bits = packed_info_extra_bits(len_info)
  write_packed_code(writer, fixed_lit_code(packed_info_sym(len_info)))
  if len_extra_bits > 0 {
    writer.write_bits(packed_info_extra_val(len_info), len_extra_bits)
  }
  let dist_info = dist_code_info(distance)
  let dist_extra_bits = packed_info_extra_bits(dist_info)
  write_packed_code(writer, fixed_dist_code(packed_info_sym(dist_info)))
  if dist_extra_bits > 0 {
    writer.write_bits(packed_info_extra_val(dist_info), dist_extra_bits)
  }
}

///|
fn write_end_block(writer : BitWriter) -> Unit {
  write_packed_code(writer, fixed_lit_code(256))
}

///|
fn insert_hash(
  data : Bytes,
  pos : Int,
  head : FixedArray[Int],
  prev : FixedArray[Int],
) -> Unit {
  if pos + 2 >= data.length() {
    return
  }
  let h = hash3(data, pos)
  prev[pos] = head[h]
  head[h] = pos
}

///|
fn build_tokens(data : Bytes) -> Array[Int] {
  let tokens : Array[Int] = []
  let len = data.length()
  let head : FixedArray[Int] = FixedArray::make(hash_size, -1)
  let prev : FixedArray[Int] = FixedArray::make(len, -1)
  let mut pos = 0
  while pos < len {
    let remaining = len - pos
    let mut best_len = 0
    let mut best_dist = 0
    if remaining >= min_match_len {
      let h = hash3(data, pos)
      let mut candidate = head[h]
      let limit = if pos > window_size { pos - window_size } else { 0 }
      let max_len = if remaining < max_match_len {
        remaining
      } else {
        max_match_len
      }
      let mut chain = 0
      while candidate >= limit && chain < max_chain {
        if data[candidate] == data[pos] &&
          data[candidate + 1] == data[pos + 1] &&
          data[candidate + 2] == data[pos + 2] {
          let l = match_len(data, candidate, pos, max_len)
          if l > best_len {
            best_len = l
            best_dist = pos - candidate
            if l == max_len {
              break
            }
          }
        }
        candidate = prev[candidate]
        chain += 1
      }
    }
    if best_len >= min_match_len {
      tokens.push(pack_token_match(best_len, best_dist))
      for i = 0; i < best_len; i = i + 1 {
        insert_hash(data, pos + i, head, prev)
      }
      pos = pos + best_len
    } else {
      tokens.push(pack_token_lit(data[pos].to_int()))
      insert_hash(data, pos, head, prev)
      pos = pos + 1
    }
  }
  tokens
}

///|
fn write_tokens_fixed(tokens : Array[Int], writer : BitWriter) -> Unit {
  for t in tokens {
    if token_is_match(t) {
      write_match(writer, token_match_len(t), token_match_dist(t))
    } else {
      write_literal(writer, token_lit_sym(t))
    }
  }
}

///|
fn fixed_tokens_byte_length(tokens : Array[Int]) -> Int {
  let mut bits = 3 // BFINAL + BTYPE
  for t in tokens {
    if token_is_match(t) {
      let len_info = length_code_info(token_match_len(t))
      bits += packed_code_len(fixed_lit_code(packed_info_sym(len_info)))
      bits += packed_info_extra_bits(len_info)
      let dist_info = dist_code_info(token_match_dist(t))
      bits += 5
      bits += packed_info_extra_bits(dist_info)
    } else {
      bits += packed_code_len(fixed_lit_code(token_lit_sym(t)))
    }
  }
  bits += packed_code_len(fixed_lit_code(256))
  (bits + 7) / 8
}

///|
fn fill_huffman_lengths(
  nodes : Array[HuffNode],
  node_id : Int,
  depth : Int,
  max_bits : Int,
  lengths : Array[Int],
) -> Bool {
  let node = nodes[node_id]
  if node.left < 0 && node.right < 0 {
    let len = if depth == 0 { 1 } else { depth }
    if len > max_bits {
      return false
    }
    lengths[node.sym] = len
    return true
  }
  if node.left >= 0 &&
    !fill_huffman_lengths(nodes, node.left, depth + 1, max_bits, lengths) {
    return false
  }
  if node.right >= 0 &&
    !fill_huffman_lengths(nodes, node.right, depth + 1, max_bits, lengths) {
    return false
  }
  true
}

///|
fn remove_active_at(active : Array[Int], active_len : Int, idx : Int) -> Int {
  for i in (idx + 1)..<active_len {
    active[i - 1] = active[i]
  }
  active_len - 1
}

///|
fn build_huffman_lengths(
  freqs : Array[Int],
  symbol_count : Int,
  max_bits : Int,
) -> Array[Int]? {
  let mut active_count = 0
  let mut first_sym = -1
  let mut second_sym = -1
  for i in 0..<symbol_count {
    if freqs[i] > 0 {
      active_count += 1
      if first_sym < 0 {
        first_sym = i
      } else if second_sym < 0 {
        second_sym = i
      }
    }
  }
  if active_count == 0 {
    return None
  }
  let lengths : Array[Int] = Array::make(symbol_count, 0)
  if active_count == 1 {
    lengths[first_sym] = 1
    return Some(lengths)
  }
  if active_count == 2 {
    lengths[first_sym] = 1
    lengths[second_sym] = 1
    return Some(lengths)
  }
  let nodes : Array[HuffNode] = []
  nodes.reserve_capacity(symbol_count * 2)
  let mut active_len = 0
  for i in 0..<symbol_count {
    if freqs[i] > 0 {
      nodes.push({ freq: freqs[i], left: -1, right: -1, sym: i })
      lengths[active_len] = nodes.length() - 1
      active_len += 1
    }
  }
  while active_len > 1 {
    let mut min1 = 0
    let mut min2 = 1
    if nodes[lengths[min2]].freq < nodes[lengths[min1]].freq {
      let tmp = min1
      min1 = min2
      min2 = tmp
    }
    for i in 2..<active_len {
      let idx = lengths[i]
      if nodes[idx].freq < nodes[lengths[min1]].freq {
        min2 = min1
        min1 = i
      } else if nodes[idx].freq < nodes[lengths[min2]].freq {
        min2 = i
      }
    }
    let a = lengths[min1]
    let b = lengths[min2]
    if min1 > min2 {
      active_len = remove_active_at(lengths, active_len, min1)
      active_len = remove_active_at(lengths, active_len, min2)
    } else {
      active_len = remove_active_at(lengths, active_len, min2)
      active_len = remove_active_at(lengths, active_len, min1)
    }
    nodes.push({
      freq: nodes[a].freq + nodes[b].freq,
      left: a,
      right: b,
      sym: -1,
    })
    lengths[active_len] = nodes.length() - 1
    active_len += 1
  }
  let root = lengths[0]
  for i in 0..<symbol_count {
    lengths[i] = 0
  }
  if !fill_huffman_lengths(nodes, root, 0, max_bits, lengths) {
    return None
  }
  Some(lengths)
}

///|
fn build_canonical_codes(
  lengths : Array[Int],
  max_bits : Int,
  scratch : Array[Int],
) -> Array[Int] {
  let codes : Array[Int] = Array::make(lengths.length(), 0)
  let mut non_zero = 0
  let mut all_one_bit = true
  for len in lengths {
    if len > 0 {
      non_zero += 1
      if len != 1 {
        all_one_bit = false
      }
    }
  }
  if non_zero == 0 {
    return codes
  }
  if non_zero <= 2 && all_one_bit {
    let mut code = 0
    for sym in 0..<lengths.length() {
      if lengths[sym] > 0 {
        codes[sym] = pack_code_len(code, 1)
        code += 1
      }
    }
    return codes
  }
  let stride = max_bits + 1
  for i in 0..<(stride * 2) {
    scratch[i] = 0
  }
  for len in lengths {
    if len > 0 {
      scratch[len] = scratch[len] + 1
    }
  }
  let mut code = 0
  for bits in 1..<=max_bits {
    code = (code + scratch[bits - 1]) << 1
    scratch[stride + bits] = code
  }
  for sym in 0..<lengths.length() {
    let len = lengths[sym]
    if len > 0 {
      let c = scratch[stride + len]
      scratch[stride + len] = c + 1
      codes[sym] = pack_code_len(deflate_reverse_bits(c, len), len)
    }
  }
  codes
}

///|
fn header_length_at(
  lit_lengths : Array[Int],
  hlit : Int,
  dist_lengths : Array[Int],
  idx : Int,
) -> Int {
  if idx < hlit {
    lit_lengths[idx]
  } else {
    dist_lengths[idx - hlit]
  }
}

///|
fn count_rle_lengths(
  lit_lengths : Array[Int],
  hlit : Int,
  dist_lengths : Array[Int],
  hdist : Int,
  cl_freq : Array[Int],
) -> Unit {
  let mut i = 0
  let total = hlit + hdist
  while i < total {
    let len = header_length_at(lit_lengths, hlit, dist_lengths, i)
    let mut run = 1
    while i + run < total &&
          header_length_at(lit_lengths, hlit, dist_lengths, i + run) == len {
      run += 1
    }
    if len == 0 {
      let mut remaining = run
      while remaining > 0 {
        if remaining >= 11 {
          let chunk = if remaining > 138 { 138 } else { remaining }
          cl_freq[18] = cl_freq[18] + 1
          remaining = remaining - chunk
        } else if remaining >= 3 {
          let chunk = if remaining > 10 { 10 } else { remaining }
          cl_freq[17] = cl_freq[17] + 1
          remaining = remaining - chunk
        } else {
          cl_freq[0] = cl_freq[0] + remaining
          remaining = 0
        }
      }
    } else {
      cl_freq[len] = cl_freq[len] + 1
      let mut remaining = run - 1
      while remaining > 0 {
        if remaining >= 3 {
          let chunk = if remaining > 6 { 6 } else { remaining }
          cl_freq[16] = cl_freq[16] + 1
          remaining = remaining - chunk
        } else {
          cl_freq[len] = cl_freq[len] + 1
          remaining = remaining - 1
        }
      }
    }
    i = i + run
  }
}

///|
fn write_rle_length_symbol(
  writer : BitWriter,
  cl_codes : Array[Int],
  sym : Int,
  extra_bits : Int,
  extra_val : Int,
) -> Unit {
  write_packed_code(writer, cl_codes[sym])
  if extra_bits > 0 {
    writer.write_bits(extra_val, extra_bits)
  }
}

///|
fn rle_length_symbol_bit_length(
  cl_lengths : Array[Int],
  sym : Int,
  extra_bits : Int,
) -> Int {
  cl_lengths[sym] + extra_bits
}

///|
fn rle_lengths_bit_length(
  lit_lengths : Array[Int],
  hlit : Int,
  dist_lengths : Array[Int],
  hdist : Int,
  cl_lengths : Array[Int],
) -> Int {
  let mut bits = 0
  let mut i = 0
  let total = hlit + hdist
  while i < total {
    let len = header_length_at(lit_lengths, hlit, dist_lengths, i)
    let mut run = 1
    while i + run < total &&
          header_length_at(lit_lengths, hlit, dist_lengths, i + run) == len {
      run += 1
    }
    if len == 0 {
      let mut remaining = run
      while remaining > 0 {
        if remaining >= 11 {
          let chunk = if remaining > 138 { 138 } else { remaining }
          bits += rle_length_symbol_bit_length(cl_lengths, 18, 7)
          remaining = remaining - chunk
        } else if remaining >= 3 {
          let chunk = if remaining > 10 { 10 } else { remaining }
          bits += rle_length_symbol_bit_length(cl_lengths, 17, 3)
          remaining = remaining - chunk
        } else {
          bits += remaining * rle_length_symbol_bit_length(cl_lengths, 0, 0)
          remaining = 0
        }
      }
    } else {
      bits += rle_length_symbol_bit_length(cl_lengths, len, 0)
      let mut remaining = run - 1
      while remaining > 0 {
        if remaining >= 3 {
          let chunk = if remaining > 6 { 6 } else { remaining }
          bits += rle_length_symbol_bit_length(cl_lengths, 16, 2)
          remaining = remaining - chunk
        } else {
          bits += rle_length_symbol_bit_length(cl_lengths, len, 0)
          remaining = remaining - 1
        }
      }
    }
    i = i + run
  }
  bits
}

///|
fn write_rle_lengths(
  lit_lengths : Array[Int],
  hlit : Int,
  dist_lengths : Array[Int],
  hdist : Int,
  cl_codes : Array[Int],
  writer : BitWriter,
) -> Unit {
  let mut i = 0
  let total = hlit + hdist
  while i < total {
    let len = header_length_at(lit_lengths, hlit, dist_lengths, i)
    let mut run = 1
    while i + run < total &&
          header_length_at(lit_lengths, hlit, dist_lengths, i + run) == len {
      run += 1
    }
    if len == 0 {
      let mut remaining = run
      while remaining > 0 {
        if remaining >= 11 {
          let chunk = if remaining > 138 { 138 } else { remaining }
          write_rle_length_symbol(writer, cl_codes, 18, 7, chunk - 11)
          remaining = remaining - chunk
        } else if remaining >= 3 {
          let chunk = if remaining > 10 { 10 } else { remaining }
          write_rle_length_symbol(writer, cl_codes, 17, 3, chunk - 3)
          remaining = remaining - chunk
        } else {
          for _ in 0..<remaining {
            write_rle_length_symbol(writer, cl_codes, 0, 0, 0)
          }
          remaining = 0
        }
      }
    } else {
      write_rle_length_symbol(writer, cl_codes, len, 0, 0)
      let mut remaining = run - 1
      while remaining > 0 {
        if remaining >= 3 {
          let chunk = if remaining > 6 { 6 } else { remaining }
          write_rle_length_symbol(writer, cl_codes, 16, 2, chunk - 3)
          remaining = remaining - chunk
        } else {
          write_rle_length_symbol(writer, cl_codes, len, 0, 0)
          remaining = remaining - 1
        }
      }
    }
    i = i + run
  }
}

///|
fn write_tokens_dynamic(
  tokens : Array[Int],
  lit_codes : Array[Int],
  dist_codes : Array[Int],
  writer : BitWriter,
) -> Unit {
  for t in tokens {
    if token_is_match(t) {
      let len_info = length_code_info(token_match_len(t))
      let len_extra_bits = packed_info_extra_bits(len_info)
      let len_code = packed_info_sym(len_info)
      write_packed_code(writer, lit_codes[len_code])
      if len_extra_bits > 0 {
        writer.write_bits(packed_info_extra_val(len_info), len_extra_bits)
      }
      let dist_info = dist_code_info(token_match_dist(t))
      let dist_extra_bits = packed_info_extra_bits(dist_info)
      let dist_code = packed_info_sym(dist_info)
      write_packed_code(writer, dist_codes[dist_code])
      if dist_extra_bits > 0 {
        writer.write_bits(packed_info_extra_val(dist_info), dist_extra_bits)
      }
    } else {
      write_packed_code(writer, lit_codes[token_lit_sym(t)])
    }
  }
  write_packed_code(writer, lit_codes[256])
}

///|
fn write_tokens_dynamic_literals(
  tokens : Array[Int],
  lit_codes : Array[Int],
  writer : BitWriter,
) -> Unit {
  for t in tokens {
    write_packed_code(writer, lit_codes[token_lit_sym(t)])
  }
  write_packed_code(writer, lit_codes[256])
}

///|
fn dynamic_tokens_bit_length(
  tokens : Array[Int],
  lit_lengths : Array[Int],
  dist_lengths : Array[Int],
) -> Int {
  let mut bits = 0
  for t in tokens {
    if token_is_match(t) {
      let len_info = length_code_info(token_match_len(t))
      bits += lit_lengths[packed_info_sym(len_info)]
      bits += packed_info_extra_bits(len_info)
      let dist_info = dist_code_info(token_match_dist(t))
      bits += dist_lengths[packed_info_sym(dist_info)]
      bits += packed_info_extra_bits(dist_info)
    } else {
      bits += lit_lengths[token_lit_sym(t)]
    }
  }
  bits + lit_lengths[256]
}

///|
fn dynamic_literal_tokens_bit_length(
  tokens : Array[Int],
  lit_lengths : Array[Int],
) -> Int {
  let mut bits = 0
  for t in tokens {
    bits += lit_lengths[token_lit_sym(t)]
  }
  bits + lit_lengths[256]
}

///|
fn deflate_compress_dynamic_tokens(
  tokens : Array[Int],
  fixed_len : Int,
) -> Bytes? {
  let lit_freq : Array[Int] = Array::make(286, 0)
  let dist_freq : Array[Int] = Array::make(30, 0)
  for t in tokens {
    if token_is_match(t) {
      let len_info = length_code_info(token_match_len(t))
      let dist_info = dist_code_info(token_match_dist(t))
      let len_code = packed_info_sym(len_info)
      let dist_code = packed_info_sym(dist_info)
      lit_freq[len_code] = lit_freq[len_code] + 1
      dist_freq[dist_code] = dist_freq[dist_code] + 1
    } else {
      let sym = token_lit_sym(t)
      lit_freq[sym] = lit_freq[sym] + 1
    }
  }
  lit_freq[256] = lit_freq[256] + 1
  let mut dist_symbol_count = 0
  let mut first_dist_sym = -1
  let mut second_dist_sym = -1
  for i in 0..<30 {
    if dist_freq[i] > 0 {
      dist_symbol_count += 1
      if first_dist_sym < 0 {
        first_dist_sym = i
      } else if second_dist_sym < 0 {
        second_dist_sym = i
      }
    }
  }
  let any_dist = dist_symbol_count > 0
  let lit_lengths = match build_huffman_lengths(lit_freq, 286, 15) {
    None => return None
    Some(v) => v
  }
  let dist_lengths : Array[Int] = if dist_symbol_count == 0 {
    dist_freq[0] = 1
    dist_freq
  } else if dist_symbol_count <= 2 {
    for i in 0..<30 {
      dist_freq[i] = 0
    }
    dist_freq[first_dist_sym] = 1
    if second_dist_sym >= 0 {
      dist_freq[second_dist_sym] = 1
    }
    dist_freq
  } else {
    match build_huffman_lengths(dist_freq, 30, 15) {
      None => return None
      Some(v) => v
    }
  }
  let mut hlit = 286
  while hlit > 257 && lit_lengths[hlit - 1] == 0 {
    hlit -= 1
  }
  let mut hdist = 30
  while hdist > 1 && dist_lengths[hdist - 1] == 0 {
    hdist -= 1
  }
  for i in 0..<19 {
    lit_freq[i] = 0
  }
  count_rle_lengths(lit_lengths, hlit, dist_lengths, hdist, lit_freq)
  let mut cl_symbol_count = 0
  let mut first_cl_sym = -1
  let mut second_cl_sym = -1
  for i in 0..<19 {
    if lit_freq[i] > 0 {
      cl_symbol_count += 1
      if first_cl_sym < 0 {
        first_cl_sym = i
      } else if second_cl_sym < 0 {
        second_cl_sym = i
      }
    }
  }
  let cl_lengths : Array[Int] = if cl_symbol_count == 0 {
    return None
  } else if cl_symbol_count <= 2 {
    for i in 0..<19 {
      lit_freq[i] = 0
    }
    lit_freq[first_cl_sym] = 1
    if second_cl_sym >= 0 {
      lit_freq[second_cl_sym] = 1
    }
    lit_freq
  } else {
    match build_huffman_lengths(lit_freq, 19, 7) {
      None => return None
      Some(v) => v
    }
  }
  let order : FixedArray[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let mut hclen = 4
  for i in 0..<order.length() {
    if cl_lengths[order[i]] != 0 {
      hclen = i + 1
    }
  }
  let mut dynamic_bits = 3 + 5 + 5 + 4 + hclen * 3
  dynamic_bits += rle_lengths_bit_length(
    lit_lengths, hlit, dist_lengths, hdist, cl_lengths,
  )
  if any_dist {
    dynamic_bits += dynamic_tokens_bit_length(tokens, lit_lengths, dist_lengths)
    if (dynamic_bits + 7) / 8 >= fixed_len {
      return None
    }
    let cl_codes = build_canonical_codes(cl_lengths, 7, lit_freq)
    let writer = BitWriter::new()
    writer.write_bits(1, 1)
    writer.write_bits(2, 2)
    writer.write_bits(hlit - 257, 5)
    writer.write_bits(hdist - 1, 5)
    writer.write_bits(hclen - 4, 4)
    for i in 0..<hclen {
      writer.write_bits(cl_lengths[order[i]], 3)
    }
    write_rle_lengths(lit_lengths, hlit, dist_lengths, hdist, cl_codes, writer)
    let lit_codes = build_canonical_codes(lit_lengths, 15, lit_freq)
    let codes = build_canonical_codes(dist_lengths, 15, lit_freq)
    write_tokens_dynamic(tokens, lit_codes, codes, writer)
    Some(writer.finish())
  } else {
    dynamic_bits += dynamic_literal_tokens_bit_length(tokens, lit_lengths)
    if (dynamic_bits + 7) / 8 >= fixed_len {
      return None
    }
    let cl_codes = build_canonical_codes(cl_lengths, 7, lit_freq)
    let writer = BitWriter::new()
    writer.write_bits(1, 1)
    writer.write_bits(2, 2)
    writer.write_bits(hlit - 257, 5)
    writer.write_bits(hdist - 1, 5)
    writer.write_bits(hclen - 4, 4)
    for i in 0..<hclen {
      writer.write_bits(cl_lengths[order[i]], 3)
    }
    write_rle_lengths(lit_lengths, hlit, dist_lengths, hdist, cl_codes, writer)
    let lit_codes = build_canonical_codes(lit_lengths, 15, lit_freq)
    write_tokens_dynamic_literals(tokens, lit_codes, writer)
    Some(writer.finish())
  }
}

///|
fn deflate_compress_fixed_tokens(tokens : Array[Int]) -> Bytes {
  let writer = BitWriter::new()
  // BFINAL=1, BTYPE=01 (fixed Huffman)
  writer.write_bits(1, 1)
  writer.write_bits(1, 2)
  write_tokens_fixed(tokens, writer)
  write_end_block(writer)
  writer.finish()
}

///|
pub fn deflate_compress_fixed(data : Bytes) -> Bytes {
  let tokens = build_tokens(data)
  deflate_compress_fixed_tokens(tokens)
}

///|
pub fn deflate_compress_best(data : Bytes) -> Bytes {
  let tokens = build_tokens(data)
  let fixed_len = fixed_tokens_byte_length(tokens)
  match deflate_compress_dynamic_tokens(tokens, fixed_len) {
    None => deflate_compress_fixed_tokens(tokens)
    Some(dynamic) =>
      if dynamic.length() < fixed_len {
        dynamic
      } else {
        deflate_compress_fixed_tokens(tokens)
      }
  }
}
