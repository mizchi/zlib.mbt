# perf(compress/flate): return exact stored output bounds

`deflate_bound` overallocates for `Standard(level=0)` and `Split(level=0)`. Stored blocks have five-byte headers and hold at most 65,535 bytes, so their size is known exactly, including one empty block. A 256 KiB input needs 262,169 bytes rather than the current bound of 262,195.

Returning the exact size lets callers pass a complete, exclusively owned output array to `Bytes::from_array`, avoiding its copy on native and linear-memory Wasm. Encoding and output bytes are unchanged; other strategies retain their existing bound calculation. Related to #4726: this independently complements its reserved frame buffers without duplicating its gzip/zlib changes.

I am publishing a final release of [mizchi/zlib](https://github.com/mizchi/zlib.mbt), then archiving its repository and directing new users to MoonBit core. This port is part of that transition.

Locally reproduced against `main@c728bce6389a` on Apple M5, macOS 26.6.2, stable moon 0.1.20261104 / moonc v0.10.20+65efd5b93, release mode. Medians of process means from three sequential processes per target, seven batches per case. Each process measures the previous and exact capacities adjacently with the same helper. Input construction and capacity arithmetic are outside timing; allocation, compressor construction, `compress_into`, conversion to Bytes and keeping the full result are included.

| Target / input | Previous bound | Exact bound |
| --- | ---: | ---: |
| native / 256 KiB | 13.91 µs | 6.55 µs |
| native / 1 MiB | 47.96 µs | 24.09 µs |
| wasm / 256 KiB | 11.00 µs | 7.15 µs |
| wasm / 1 MiB | 45.41 µs | 24.64 µs |
| JS / 256 KiB | 670.90 µs | 651.23 µs |
| JS / 1 MiB | 2.50 ms | 2.62 ms |

Native empty/1 KiB controls remain about 0.88/0.87 µs. JS still copies during conversion and showed no consistent improvement; the 1 MiB case was 4.8% slower. These measurements cover materializing stored output through `compress_into`, not the existing gzip/zlib compression APIs.

```sh
moon bench compress/flate/stored_bound_wbtest.mbt --release --target native --no-parallelize
moon bench compress/flate/stored_bound_wbtest.mbt --release --target wasm --no-parallelize
```

Tests cover block boundaries, empty input, input/output offsets, dictionaries, `fast_store`, one-byte-short output buffers and the last representable Int32 capacity. Whole-module `moon check --target all --deny-warn`, all-target tests (37,455 total), `moon bundle --all`, package `moon info` / `moon fmt`, and the license check passed. Release tests for flate/zlib/gzip/checksum passed on all four targets (799 total). No `.mbti` changes.
