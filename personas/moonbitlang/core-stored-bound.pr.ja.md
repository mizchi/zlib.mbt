# perf(compress/flate): return exact stored output bounds

`deflate_bound` は Standard / Split の level 0 にも余分な容量を返します。stored block のヘッダーは5 bytesで、1 blockは最大65535 bytesなので、空入力の1 blockを含めて実サイズを求められます。256 KiBの入力では262195から262169 bytesになります。

全領域を使った排他所有の配列を `Bytes::from_array` に渡すと、native / linear-memory Wasmではコピーを避けられます。圧縮器と出力バイト列は変えず、他のstrategyの上限計算も維持します。Related to #4726。既存のgzip/zlibフレーム最適化を重複させず、その予約領域を実サイズにできる独立した追加改善です。

ローカル再現: main@c728bce6389a、Apple M5、macOS 26.6.2、stable moon 0.1.20261104 / moonc v0.10.20+65efd5b93、release。各targetを3プロセスずつ直列実行し、各7バッチのプロセス平均から中央値を取りました。同じhelperで旧上限と新上限を隣接測定します。入力構築と上限計算は計測外で、確保、圧縮器の構築、compress_into、Bytes変換、返り値全体の保持を含みます。

| Target / input | 旧上限 | 正確な上限 |
| --- | ---: | ---: |
| native / 256 KiB | 13.91 µs | 6.55 µs |
| native / 1 MiB | 47.96 µs | 24.09 µs |
| wasm / 256 KiB | 11.00 µs | 7.15 µs |
| wasm / 1 MiB | 45.41 µs | 24.64 µs |
| JS / 256 KiB | 670.90 µs | 651.23 µs |
| JS / 1 MiB | 2.50 ms | 2.62 ms |

nativeの空入力/1 KiBは約0.88/0.87 µsでほぼ同等です。JSは変換でコピーが残り、一貫した改善はなく、1 MiBは4.8%遅い結果でした。これはcompress_intoからstored出力をBytesへ変換する処理の測定で、既存のgzip/zlib圧縮API全体の数字ではありません。

```sh
moon bench compress/flate/stored_bound_wbtest.mbt --release --target native --no-parallelize
moon bench compress/flate/stored_bound_wbtest.mbt --release --target wasm --no-parallelize
```

テストはblock境界、空入力、input/outputのoffset、dictionary、fast_store、1 byte足りないoutput、Int32容量の上端を確認します。全モジュールの全target check、全target test（37455件）、bundle、対象packageのinfo/fmt、license checkが通りました。flate/zlib/gzip/checksumのrelease testは4targetで799件成功。mbti差分はありません。
