///| Bit reader for deflate streams (LSB-first)

///|
priv struct BitReader {
  data : Bytes
  mut byte_pos : Int
  mut bit_buf : Int
  mut bit_count : Int
}

///|
fn BitReader::new(data : Bytes, start : Int) -> BitReader {
  { data, byte_pos: start, bit_buf: 0, bit_count: 0 }
}

///|
fn BitReader::ensure_bits(self : BitReader, n : Int) -> Unit raise ZlibError {
  while self.bit_count < n {
    if self.byte_pos >= self.data.length() {
      raise ZlibError::InvalidData("Unexpected end of deflate stream")
    }
    let b = self.data[self.byte_pos].to_int()
    self.byte_pos = self.byte_pos + 1
    self.bit_buf = self.bit_buf | (b << self.bit_count)
    self.bit_count = self.bit_count + 8
  }
}

///|
fn BitReader::peek_bits(self : BitReader, n : Int) -> Int raise ZlibError {
  if n == 0 {
    return 0
  }
  self.ensure_bits(n)
  let mask = (1 << n) - 1
  self.bit_buf & mask
}

///|
fn BitReader::drop_bits(self : BitReader, n : Int) -> Unit {
  if n == 0 {
    return
  }
  self.bit_buf = self.bit_buf >> n
  self.bit_count = self.bit_count - n
}

///|
fn BitReader::read_bits(self : BitReader, n : Int) -> Int raise ZlibError {
  let result = self.peek_bits(n)
  self.drop_bits(n)
  result
}

///|
fn BitReader::align_byte(self : BitReader) -> Unit {
  self.bit_buf = 0
  self.bit_count = 0
}

///|

///|
fn BitReader::read_u16_le_aligned(self : BitReader) -> Int raise ZlibError {
  if self.bit_count != 0 {
    self.align_byte()
  }
  if self.byte_pos + 2 > self.data.length() {
    raise ZlibError::InvalidData("Unexpected end of deflate stream")
  }
  let b0 = self.data[self.byte_pos].to_int()
  let b1 = self.data[self.byte_pos + 1].to_int()
  self.byte_pos = self.byte_pos + 2
  b0 | (b1 << 8)
}

///|
fn BitReader::read_bytes_aligned(
  self : BitReader,
  output : Array[Byte],
  len : Int,
) -> Unit raise ZlibError {
  if self.bit_count != 0 {
    self.align_byte()
  }
  if self.byte_pos + len > self.data.length() {
    raise ZlibError::InvalidData("Unexpected end of deflate stream")
  }
  for i in 0..<len {
    output.push(self.data[self.byte_pos + i])
  }
  self.byte_pos = self.byte_pos + len
}

///|
fn BitReader::offset(self : BitReader) -> Int {
  self.byte_pos
}
