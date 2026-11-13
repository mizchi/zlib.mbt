# Stored 出力上限の追加最適化

提出先: [moonbitlang/core#4844](https://github.com/moonbitlang/core/pull/4844)。

当初の zlib/gzip 包装の事前確保は、既存の [#4726](https://github.com/moonbitlang/core/pull/4726) に含まれていた。その変更は重複して提出せず、`deflate_bound` が level 0 に正確な stored サイズを返す追加改善を独立した PR にした。Standard / Split の level 0 が対象で、エンコード結果と他の戦略は変えない。

256 KiB の場合、従来の上限262195 bytesに対して実際の出力は262169 bytes。わずかな余剰でも、出力だけを切り出すと部分 view になり、native / linear-memory Wasm の `Bytes::from_array` でコピーを避けられない。正確な上限で全バッファを使えば、排他所有の配列をそのまま Bytes にできる。計算はこのリポジトリの `stored_deflate_len` と同じ stored block の性質を使う。

## 測定

Apple M5 / macOS 26.6.2、stable moon 0.1.20261104 / moonc v0.10.20+65efd5b93、release。各ターゲットを3プロセスずつ直列実行し、各7バッチの平均からプロセス間の中央値を取った。同じ helper で旧容量と正確な容量を隣接測定し、返り値全体を `b.keep` に渡した。入力構築と容量計算は計測外、確保・圧縮器の構築・compress_into・Bytes変換・結果の保持は計測内。

| Target | 入力 | 旧容量 | 正確な容量 | 速度比 |
| --- | --- | ---: | ---: | ---: |
| native | 256 KiB | 13.91 µs | 6.55 µs | 2.12× |
| native | 1 MiB | 47.96 µs | 24.09 µs | 1.99× |
| wasm | 256 KiB | 11.00 µs | 7.15 µs | 1.54× |
| wasm | 1 MiB | 45.41 µs | 24.64 µs | 1.84× |
| JS | 256 KiB | 670.90 µs | 651.23 µs | 1.03× |
| JS | 1 MiB | 2.50 ms | 2.62 ms | 0.95× |

native の空入力と1 KiBは約0.88 / 0.87 µsでほぼ同等。JSには一貫した改善がなく、1 MiBは約4.8%遅い結果で、この点もPR本文に明記した。これは公開 flate API の compress_into で作った stored 出力を Bytes にする処理で、現在の gzip/zlib 圧縮全体の数字ではない。他のユーザープロセスが動く共有マシンでのローカル測定。

## 再現

```bash
moon bench compress/flate/stored_bound_wbtest.mbt --release --target native --no-parallelize
moon bench compress/flate/stored_bound_wbtest.mbt --release --target wasm --no-parallelize
moon bench compress/flate/stored_bound_wbtest.mbt --release --target js --no-parallelize
```

base は `c728bce6389a3b53111b4ccfb7b6d94dc96d014d`、提出コミットは `3bdbd9443fd7370a225bf93df6d965d3b7fd6d66`。ローカル worktree は `/Users/mz/ghq/github.com/moonbitlang/core-stored-bound`、ブランチは `perf/flate-stored-bound`。

## 検証

- Red: 変更前は出力サイズとの一致テストが失敗し、Int32上端のテストは旧上限の過大評価で overflow panic となった。
- Green: 空入力と65535-byte block境界、入力/outputのoffset、dictionary、fast_store、1 byte足りないoutput、Int32容量上端を4ターゲットで検証した。
- 全モジュールの check と全ターゲットtestは37455件成功（wasm 9616、wasm-gc 9037、JS 9213、native 9589）。
- flate/zlib/gzip/checksum の release testは799件成功（wasm 199、wasm-gc 194、JS 194、native 212）。
- bundle、対象のinfo/fmt、HawkEyeライセンス検査が通過。ヘッダーを一時的に除くと検査が失敗することも確認し、元に戻した。公開mbti差分なし。
- PR本文の英語コーパス85件に対して表層lintは0件。投稿ゲートは visible 2453/3363 chars / language en / external repository references 0。別の読み手による確認は PASS。

生データと全サイズの集計は [results/stored-bound](results/stored-bound/) に保存した。
