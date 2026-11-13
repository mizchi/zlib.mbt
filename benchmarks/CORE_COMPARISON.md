# MoonBit core と mizchi/zlib の比較

2026-11-13、Apple M5 / macOS 26.6.2、Node.js v24.22.2。

core は今回の合成入力では圧縮・展開とも概ね速く、圧縮率も良い。JS の stored 圧縮は mizchi/zlib が速い。移植は、最終サイズを先に確保してフレームを組み立てる方法を native / 通常 Wasm の core zlib/gzip に適用した。

## 比較条件

- ツールチェーン: moonc `v0.10.20+65efd5b93`、moon `0.1.20261104`。比較対象はインストール済み core。ソースの SHA-256 は各 metadata JSON に記録した。
- 入力は 1 KiB の連番、および 256 KiB の連番・反復英文・固定シード xorshift32。実データのコーパスではなく、一般的なファイル全体の性能は断定しない。
- 同一プロセス内で `@bench.single_bench(count=5)` を使い、中央値を比較。単位は µs。入力生成・圧縮済み入力の準備・プロセス起動は計測外。API 内の確保・コピー・チェックサムは含む。
- 展開は core level 6 で作った同一の圧縮列を両実装へ渡し、計測前に復元内容を照合した。
- 圧縮は mizchi/zlib の既定 API と core `Standard(level=6)`。探索方式・圧縮レベルを同等に調整した比較ではないため、出力サイズも記録した。
- mizchi/zlib の `gzip_compress` は stored 出力。gzip の通常圧縮の速さは比較せず、stored 同士を比較する。JSON の `compress/gzip` 行にもこの差がある。

## 256 KiB での速度比

値は 3 種類の入力・対象フォーマットの最小〜最大。倍率は表の実装が速いことを表す。

| Target | 展開: core | deflate/zlib 圧縮: core | zlib/gzip stored 圧縮 |
| --- | ---: | ---: | ---: |
| native | 2.54–7.73× | 1.40–3.27× | core 2.32–5.59× |
| js | 1.12–1.78× | 1.14–1.49× | mizchi/zlib 2.36–3.35× |
| wasm | 10.65–62.28× | 2.90–7.38× | core 3.48–7.00× |

native の random/zlib/core 圧縮には標準偏差約48%のばらつきがあった。このケースの厳密な倍率は判断材料にせず、元データの中央値・分散を併記して残した。

native / 256 KiB の連番入力の実測:

| 処理 | mizchi/zlib (µs) | core (µs) | 出力 bytes: mizchi → core |
| --- | ---: | ---: | ---: |
| decompress deflate | 120.01 | 26.75 | 1378 → 1378 |
| decompress zlib | 189.04 | 41.46 | 1384 → 1384 |
| decompress gzip | 210.27 | 82.78 | 1396 → 1396 |
| compress deflate | 544.79 | 178.72 | 1972 → 1378 |
| compress zlib | 626.57 | 191.88 | 1978 → 1384 |
| store zlib | 188.25 | 47.93 | 262175 → 262175 |
| store gzip | 207.59 | 87.52 | 262187 → 262187 |

展開行の出力 bytes 欄は、両デコーダーへ渡した圧縮列のサイズ。各結果の完全な情報は [results](results/) の JSONL / CSV / metadata を参照。

## core 向け移植

対象は upstream `c728bce6389a3b53111b4ccfb7b6d94dc96d014d`。作業ブランチは `perf/zlib-port-20261113`、worktree は `/Users/mz/ghq/github.com/moonbitlang/core-zlib-perf`。比較用の同梱 core と、この upstream の変更前後測定は別に記録している。

[core-frame-preallocation.patch](core-frame-preallocation.patch) を用意した。元の zlib/gzip 包装は伸長可能な Buffer にヘッダー、圧縮データ、トレーラーを追記していた。mizchi/zlib の `zlib_compress_stored` / `zlib_compress` と同様に、必要な全長を一度確保し、既存の安全な blit で圧縮データを置き、チェックサムを書き込む。native / 通常 Wasm では排他的に所有する配列を `Bytes::from_array` に渡せるため、最終変換のコピーも避けられる。

公開 API と圧縮結果は維持。整数加算のオーバーフローは確保前に検査する。プリセット辞書の DICTID、入力 view のオフセット、空入力、stored block の境界をテストした。256 KiB のトレーラーは Python zlib の独立した参照値とも照合した。

包装のみのベンチは圧縮本体を含まず、チェックサムは含む。次表の level 0 行は圧縮 API 全体。いずれも 7 バッチの平均で、比較表の中央値とは集計方法が異なる。

| Target | 処理 | 変更前 (µs) | 変更後 (µs) | 時間短縮 |
| --- | --- | ---: | ---: | ---: |
| native | gzip frame 1024 | 0.298 | 0.237 | 20.8% |
| native | gzip frame 262144 | 72.390 | 61.080 | 15.6% |
| native | gzip compress level 0 262144 | 88.630 | 79.940 | 9.8% |
| native | zlib frame 1024 | 0.141 | 0.086 | 39.1% |
| native | zlib frame 262144 | 29.150 | 19.670 | 32.5% |
| native | zlib compress level 0 262144 | 48.870 | 39.420 | 19.3% |
| wasm | gzip frame 1024 | 0.596 | 0.454 | 23.8% |
| wasm | gzip compress level 0 262144 | 139.620 | 127.560 | 8.6% |
| wasm | zlib frame 1024 | 0.251 | 0.139 | 44.6% |
| wasm | zlib frame 262144 | 31.990 | 25.200 | 21.2% |
| wasm | zlib compress level 0 262144 | 51.910 | 45.050 | 13.2% |

Wasm の gzip 包装 256 KiB は変更前の標準偏差が約20%あり、上表から除いた。native の zlib level 6 も変更前のばらつきが大きく、見かけの約43%短縮は改善実績として採用しない。通常圧縮では包装対象が小さく、gzip native level 6 は約0.3%、zlib Wasm level 6 は約0.3%遅いという、実質的に差が小さい測定だった。

最終サイズを Buffer の size_hint に渡す案と、直接確保する案を JS でも試したが、JS では安定した改善が得られず遅くなったため採用していない。最終パッチの JS / Wasm-GC は従来の Buffer 経路を使う。SIMD・CRC・LZ77 は core が既に強い最適化を持つため、今回はこちらの実装へ置き換えなかった。

## 再実行

このリポジトリで:

```bash
just bench-core native
just bench-core js
just bench-core wasm
```

各コマンドは計72件を直列測定し、`benchmarks/results/core-compare-<target>.{jsonl,csv,metadata.json}` に保存する。CPU を使うテストや他のベンチマークと並行実行しない。

core の clean checkout にパッチを適用した後:

```bash
moon check compress/zlib compress/gzip --target all --deny-warn
moon test compress/flate compress/zlib compress/gzip internal/checksum --target all
moon bench compress/zlib compress/gzip --target native --no-parallelize
moon bench compress/zlib compress/gzip --target wasm --no-parallelize
```

変更前を再測定する場合は、パッチ中の `frame_wbtest.mbt` 2ファイルとその bench import だけをベースへ追加する。包装の単独測定と、level 0 / level 6 の圧縮全体を分けて比較できる。

## 検証

- zlib: `just release-check`、`moon check --target all --deny-warn`。JS 37件、native 40件、Wasm/Wasm-GC 各37件。相互互換テストは空入力から65,537 bytesまで、3入力×3形式×core level 0/1/6 と mizchi の既定/stored を確認した。
- Node.js の zlib とのクロス検証: 42件成功。CLI 引数処理も JS / native で確認した。
- core: 対象パッケージの全ターゲット check、flate/zlib/gzip/checksum の計803件成功（Wasm 200、Wasm-GC 195、JS 195、native 213）。公開 `.mbti` に差分なし。
- 現行ツールチェーンで再実行できるよう、zlib の x を0.5.7へ更新し、未使用の async 依存を削除した。現行 formatter による Int32/UInt32 表記、derive、manifest の移行と、テスト/API の非推奨構文の更新も含む。圧縮アルゴリズム自体は変更していない。
- パッチは clean な対象コミットへの `git apply --check` と、検証済み worktree からの逆適用チェックを確認した。
- 包装処理は既存の open PR [#4726](https://github.com/moonbitlang/core/pull/4726) と重複していたため、同じ変更を重ねて投稿していない。追加改善として stored 出力上限を厳密にする [#4844](https://github.com/moonbitlang/core/pull/4844) を提出した。新しい測定は [CORE_STORED_BOUND_PR.md](CORE_STORED_BOUND_PR.md) に記録した。

参照: [MoonBit 公式更新情報](https://www.moonbitlang.com/updates)、[移植先の core zlib](https://github.com/moonbitlang/core/blob/c728bce6389a3b53111b4ccfb7b6d94dc96d014d/compress/zlib/zlib.mbt)。
