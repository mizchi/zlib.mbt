# moonbitlang/core への移行とアーカイブ判断

2026-11-13。新規利用を core に誘導する方針は妥当。既存ユーザーにとっては API の置換だけでは挙動が一致しないため、移行案内と最終リリースを整えてからアーカイブする。

## 対応する API

| mizchi/zlib | core の移行先 | 注意点 |
| --- | --- | --- |
| `zlib_compress` | `compress/zlib.compress` | 圧縮方式・出力バイト列は変わる |
| `zlib_compress_stored` | 同上、`strategy=Standard(level=0)` | stored 出力を明示する |
| `deflate_compress` / `deflate_compress_best` | `compress/flate.deflate_all` | 通常は既定の level 6。Split / Optimal も選べる |
| `deflate_compress_stored` | 同上、`strategy=Standard(level=0)` | 空入力を含めて出力バイト列の一致を契約にしない |
| `deflate_compress_fixed` | 直接対応する公開の固定 Huffman 専用指定はない | 固定出力が必要な利用者は互換コードを残す |
| `gzip_compress` / `gzip_compress_stored` | `compress/gzip.compress`、stored を維持するなら level 0 | こちらの `gzip_compress` は無圧縮だが、core の既定は level 6 |
| `deflate_decompress` | `compress/flate.inflate_exact` | 明示的な出力上限を渡す |
| `zlib_decompress` | `compress/zlib.decompress` | 明示的な出力上限を渡す。両者とも余分な入力を拒否する |
| `gzip_decompress` | `compress/gzip.decompress` | 下記のメンバー・末尾データの挙動が異なる |
| `deflate_decompress_at` | 入力を start で slice し、`flate.inflate_prefix` | 戻り値の consumed は slice の先頭基準。元の絶対位置は start を加える |
| `zlib_decompress_at` / `gzip_decompress_at` | 各 `Decoder` の streaming API | consumed と `unused_input()` を使い、読み込んだ先のデータを回収する。単純な関数名置換にはならない |
| `adler32` / `crc32` と fixed 版 | 同等の core 公開 API は確認できない | `core/internal/checksum` は外部利用向けではない。必要なら小さな互換パッケージを残す |
| `mizchi/zlib/native` | core は pure MoonBit 実装 | システムの `libz` を明示的に選ぶラッパーの直接代替にはならない |

## 挙動の差

こちらは全展開 API で既定256 MiBの上限を持つ。core の既定は Bytes の容量までなので、上限を維持する場合は呼び出し側で指定する。インストール済み2026-11-05の core ではラベルは `max_output`、main@c728bce6389a では `max_output_bytes` に改名されている。後者は旧ラベルを移行用エイリアスとして残している。

こちらの gzip は一つのメンバーを復元し、余分な入力をエラーにする。core の whole-buffer gzip は複数メンバーを結合し、次のメンバーとして始まらない末尾データを無視する。同じ検証規則を保つには、`Decoder(multistream=false)` と入力消費量・未使用入力の検査で互換層を作る必要がある。

エラー型は `ZlibError` 一種類から、flate / zlib / gzip ごとの型・分類へ分かれる。パターンマッチとエラーの比較も見直す。core はプリセット辞書、キャンセル、streaming を提供しており、機能面では今回の主要 API を上回る。

2026-11-05のリリースで圧縮パッケージが core に加わったが、現在は experimental 指定がある。利用側の `moon.pkg` に `options("allow-experimental-packages": true)` を追加し、使うツールチェーンと API ラベルを固定する。

## 推奨する手順

1. README 冒頭で新規プロジェクトには core を案内し、上の互換差分へリンクする。
2. 固定 Huffman、公開チェックサム、システム libz ラッパーの利用者が残るか確認する。必要な部分だけを独立した互換パッケージにするか、最終リリースに残す。
3. 現行ツールチェーンでのビルド修正と比較ベンチを最終リリースとして保存し、最適化の upstream PR [#4844](https://github.com/moonbitlang/core/pull/4844) と既存の包装最適化 [#4726](https://github.com/moonbitlang/core/pull/4726) をリンクする。過去の公開バージョンとタグを残す。
4. ユーザーへの案内とリリースを公開した後、リポジトリをアーカイブする。

通常の圧縮・展開のために実装全体を維持し続ける理由は小さい。ただし JS の stored 圧縮は今回の入力ではこちらが約2.4〜3.3倍速く、そこに依存する利用者は実際の入力で再測定した方がよい。比較は [CORE_COMPARISON.md](CORE_COMPARISON.md) に記録した。

検討を経て、0.4.11 を最終版として公開し、リポジトリをアーカイブする方針を確定した。利用者向けの移行案内は [MIGRATION.md](../MIGRATION.md) を参照。

参照: [公式更新情報](https://www.moonbitlang.com/updates)、[core flate API](https://github.com/moonbitlang/core/blob/c728bce6389a3b53111b4ccfb7b6d94dc96d014d/compress/flate/pkg.generated.mbti)、[core gzip の全展開 API](https://github.com/moonbitlang/core/blob/c728bce6389a3b53111b4ccfb7b6d94dc96d014d/compress/gzip/gzip.mbt)。
