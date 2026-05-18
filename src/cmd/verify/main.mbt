///|
/// CLI for cross-verification: read binary, compress/decompress, write binary
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 5 {
    println(
      "Usage: verify <compress|decompress> <zlib|deflate|gzip> <input> <output>",
    )
    @sys.exit(1)
  }
  let mode = args[1]
  let format = args[2]
  let input_path = args[3]
  let output_path = args[4]
  let input_r : Result[Bytes, _] = try? @fs.read_file_to_bytes(input_path)
  guard input_r is Ok(input) else {
    println("Error: failed to read \{input_path}")
    @sys.exit(1)
  }
  let result_r : Result[Bytes, _] = try? (match (mode, format) {
    ("compress", "zlib") => @zlib.zlib_compress(input)
    ("compress", "deflate") => @zlib.deflate_compress(input)
    ("compress", "gzip") => @zlib.gzip_compress_stored(input)
    ("decompress", "zlib") => @zlib.zlib_decompress(input)
    ("decompress", "deflate") => @zlib.deflate_decompress(input)
    ("decompress", "gzip") => @zlib.gzip_decompress(input)
    _ => abort("Unknown mode/format: \{mode} \{format}")
  })
  guard result_r is Ok(output) else {
    guard result_r is Err(e)
    println("Error: \{e}")
    @sys.exit(1)
  }
  let write_r : Result[Unit, _] = try? @fs.write_bytes_to_file(
    output_path, output,
  )
  guard write_r is Ok(_) else {
    println("Error: failed to write \{output_path}")
    @sys.exit(1)
  }
  println("OK \{input.length()} -> \{output.length()}")
}
