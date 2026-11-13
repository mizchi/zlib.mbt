///|
fn make_input(kind : String, size : Int32) -> Bytes {
  let text = b"MoonBit compression benchmark: readable text, repeated words, numbers 0123456789.\n"
  let mut state = 0x12345678U
  Bytes::from_array(
    FixedArray::makei(size, i => {
      match kind {
        "pattern" => (i % 256).to_byte()
        "text" => text[i % text.length()]
        "random" => {
          state = state ^ (state << 13)
          state = state ^ (state >> 17)
          state = state ^ (state << 5)
          (state & 255U).to_byte()
        }
        _ => abort("unknown input: \{kind}")
      }
    }),
  )
}

///|
fn local_compress(format : String, input : Bytes, stored : Bool) -> Bytes {
  match (format, stored) {
    ("deflate", false) => @local.deflate_compress(input)
    ("deflate", true) => @local.deflate_compress_stored(input)
    ("zlib", false) => @local.zlib_compress(input)
    ("zlib", true) => @local.zlib_compress_stored(input)
    ("gzip", _) => @local.gzip_compress_stored(input)
    _ => abort("unknown format: \{format}")
  }
}

///|
fn core_compress(format : String, input : Bytes, level : Int32) -> Bytes {
  let strategy = @flate.Standard(level~)
  match format {
    "deflate" => @flate.deflate_all(input, strategy~)
    "zlib" => @core_zlib.compress(input, strategy~)
    "gzip" => @gzip.compress(input, strategy~)
    _ => abort("unknown format: \{format}")
  }
}

///|
fn local_decompress(format : String, input : Bytes) -> Bytes raise {
  match format {
    "deflate" => @local.deflate_decompress(input)
    "zlib" => @local.zlib_decompress(input)
    "gzip" => @local.gzip_decompress(input)
    _ => abort("unknown format: \{format}")
  }
}

///|
fn core_decompress(format : String, input : Bytes) -> Bytes raise {
  match format {
    "deflate" => @flate.inflate_exact(input)
    "zlib" => @core_zlib.decompress(input)
    "gzip" => @gzip.decompress(input)
    _ => abort("unknown format: \{format}")
  }
}

///|
fn measure(
  operation : String,
  format : String,
  kind : String,
  size : Int32,
  implementation : String,
  encoded_size : Int32,
  f : () -> Bytes,
) -> Unit {
  // Observe each result inside the process; allocation is part of the API cost.
  let sink : FixedArray[Int32] = [0]
  let summary = @bench.single_bench(count=5, () => {
    let result = f()
    sink[0] = result.length() +
      (if result.is_empty() { 0 } else { result[0].to_int() })
  })
  let record : @json.Json = {
    "operation": operation,
    "format": format,
    "kind": kind,
    "input_bytes": size,
    "implementation": implementation,
    "compressed_bytes": encoded_size,
    "summary": @json.ToJson::to_json(summary),
    "sink": sink[0],
  }
  println(record.stringify())
}

///|
fn main {
  for
    (kind, size) in [
      ("pattern", 1024),
      ("pattern", 262144),
      ("text", 262144),
      ("random", 262144),
    ] {
    let input = make_input(kind, size)
    for format in ["deflate", "zlib", "gzip"] {
      let encoded = core_compress(format, input, 6)
      // Both inflaters receive exactly the same bytes, outside the timed setup.
      assert_eq(try! local_decompress(format, encoded), input) catch {
        _ => abort("local decoder mismatch")
      }
      assert_eq(try! core_decompress(format, encoded), input) catch {
        _ => abort("core decoder mismatch")
      }
      measure("decompress", format, kind, size, "mizchi", encoded.length(), () => {
        try! local_decompress(format, encoded)
      })
      measure("decompress", format, kind, size, "core", encoded.length(), () => {
        try! core_decompress(format, encoded)
      })
      let local_encoded = local_compress(format, input, false)
      measure(
        "compress",
        format,
        kind,
        size,
        "mizchi",
        local_encoded.length(),
        () => local_compress(format, input, false),
      )
      measure("compress", format, kind, size, "core-l6", encoded.length(), () => {
        core_compress(format, input, 6)
      })
      let stored = local_compress(format, input, true)
      measure("store", format, kind, size, "mizchi", stored.length(), () => {
        local_compress(format, input, true)
      })
      let core_stored = core_compress(format, input, 0)
      measure("store", format, kind, size, "core-l0", core_stored.length(), () => {
        core_compress(format, input, 0)
      })
    }
  }
}
