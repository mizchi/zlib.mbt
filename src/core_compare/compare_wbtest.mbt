///|
test "both codecs decode each other's stored and compressed streams" {
  for size in [0, 1, 2, 3, 15, 16, 257, 258, 1024, 32769, 65537] {
    for kind in ["pattern", "text", "random"] {
      let input = make_input(kind, size)
      for format in ["deflate", "zlib", "gzip"] {
        for level in [0, 1, 6] {
          let encoded = core_compress(format, input, level)
          assert_eq(local_decompress(format, encoded), input)
          assert_eq(core_decompress(format, encoded), input)
        }
        let encoded = local_compress(format, input, false)
        assert_eq(core_decompress(format, encoded), input)
        let stored = local_compress(format, input, true)
        assert_eq(core_decompress(format, stored), input)
      }
    }
  }
}
