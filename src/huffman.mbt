///| Huffman tree for deflate decoding

///|
priv struct HuffmanTree {
  left : Array[Int]
  right : Array[Int]
  symbol : Array[Int]
  table_bits : Int
  table_symbol : FixedArray[Int]
  table_len : FixedArray[Int]
}

///|
fn HuffmanTree::new(table_bits : Int) -> HuffmanTree {
  let size = if table_bits <= 0 { 0 } else { 1 << table_bits }
  {
    left: [-1],
    right: [-1],
    symbol: [-1],
    table_bits,
    table_symbol: FixedArray::make(size, -1),
    table_len: FixedArray::make(size, 0),
  }
}

///|
fn HuffmanTree::add_node(self : HuffmanTree) -> Int {
  self.left.push(-1)
  self.right.push(-1)
  self.symbol.push(-1)
  self.left.length() - 1
}

///|
fn HuffmanTree::insert(
  self : HuffmanTree,
  code : Int,
  len : Int,
  sym : Int,
) -> Unit raise ZlibError {
  if len == 0 {
    return
  }
  let mut node = 0
  for i in 0..<len {
    let bit = (code >> i) & 1
    let next = if bit == 0 { self.left[node] } else { self.right[node] }
    let child = if next == -1 {
      let idx = self.add_node()
      if bit == 0 {
        self.left[node] = idx
      } else {
        self.right[node] = idx
      }
      idx
    } else {
      next
    }
    node = child
  }
  if self.symbol[node] != -1 {
    raise ZlibError::InvalidData("Invalid Huffman code")
  }
  self.symbol[node] = sym
}

///|
fn HuffmanTree::decode(
  self : HuffmanTree,
  reader : BitReader,
) -> Int raise ZlibError {
  if self.table_bits > 0 {
    let bits = reader.peek_bits(self.table_bits)
    let sym = self.table_symbol[bits]
    if sym != -1 {
      let len = self.table_len[bits]
      reader.drop_bits(len)
      return sym
    }
  }
  let mut node = 0
  while true {
    let bit = reader.read_bits(1)
    node = if bit == 0 { self.left[node] } else { self.right[node] }
    if node == -1 {
      raise ZlibError::InvalidData("Invalid Huffman code")
    }
    if self.symbol[node] != -1 {
      return self.symbol[node]
    }
  }
  raise ZlibError::InvalidData("Unreachable")
}

///|
fn reverse_bits(code : Int, len : Int) -> Int {
  let mut result = 0
  for i = 0; i < len; i = i + 1 {
    let bit = (code >> i) & 1
    result = (result << 1) | bit
  }
  result
}

///|
fn build_huffman_tree(
  lengths : Array[Int],
  max_bits : Int,
) -> HuffmanTree raise ZlibError {
  let bl_count : FixedArray[Int] = FixedArray::make(max_bits + 1, 0)
  for len in lengths {
    if len > 0 {
      bl_count[len] = bl_count[len] + 1
    }
  }
  let next_code : FixedArray[Int] = FixedArray::make(max_bits + 1, 0)
  let mut code = 0
  for bits = 1; bits <= max_bits; bits = bits + 1 {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }
  let table_bits = if max_bits > 9 { 9 } else { max_bits }
  let tree = HuffmanTree::new(table_bits)
  for i = 0; i < lengths.length(); i = i + 1 {
    let len = lengths[i]
    if len > 0 {
      let c = next_code[len]
      next_code[len] = next_code[len] + 1
      let rev = reverse_bits(c, len)
      tree.insert(rev, len, i)
      if len <= table_bits {
        let fill = 1 << (table_bits - len)
        for j in 0..<fill {
          let idx = rev | (j << len)
          tree.table_symbol[idx] = i
          tree.table_len[idx] = len
        }
      }
    }
  }
  tree
}
