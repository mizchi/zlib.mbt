///|
/// Run with:
/// - moon bench --target js
/// - moon bench --target native

///|
let bench_size : Int = 256 * 1024

///|
fn make_bench_bytes(size : Int) -> Bytes {
  let buf : Array[Byte] = []
  for i = 0; i < size; i = i + 1 {
    buf.push((i % 256).to_byte())
  }
  Bytes::from_array(FixedArray::makei(buf.length(), fn(i) { buf[i] }))
}

///|
let bench_data : Bytes = make_bench_bytes(bench_size)

///|
let bench_deflate_stored : Bytes = deflate_compress_stored(bench_data)

///|
let bench_zlib_stored : Bytes = zlib_compress_stored(bench_data)

///|
let bench_gzip_stored : Bytes = gzip_compress_stored(bench_data)

///|
test "bench adler32" (b : @bench.T) {
  b.bench(fn() { b.keep(adler32(bench_data)) })
}

///|
test "bench crc32" (b : @bench.T) {
  b.bench(fn() { b.keep(crc32(bench_data)) })
}

///|
test "bench deflate_compress_stored" (b : @bench.T) {
  b.bench(fn() { b.keep(deflate_compress_stored(bench_data)) })
}

///|
test "bench deflate_decompress" (b : @bench.T) {
  b.bench(fn() { b.keep(try! deflate_decompress(bench_deflate_stored)) })
}

///|
test "bench zlib_compress_stored" (b : @bench.T) {
  b.bench(fn() { b.keep(zlib_compress_stored(bench_data)) })
}

///|
test "bench zlib_decompress" (b : @bench.T) {
  b.bench(fn() { b.keep(try! zlib_decompress(bench_zlib_stored)) })
}

///|
test "bench gzip_compress_stored" (b : @bench.T) {
  b.bench(fn() { b.keep(gzip_compress_stored(bench_data)) })
}

///|
test "bench gzip_decompress" (b : @bench.T) {
  b.bench(fn() { b.keep(try! gzip_decompress(bench_gzip_stored)) })
}
