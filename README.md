# mizchi/zlib

Pure MoonBit zlib/deflate implementation. Currently supports stored blocks and inflate helpers.

## Quick Commands

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just test-update  # update snapshot tests
just info      # generate type definition files
```

## Project Structure

```
zlib/
├── moon.mod.json
├── src/
│   ├── moon.pkg
│   ├── zlib.mbt
│   ├── inflate.mbt
│   ├── huffman.mbt
│   ├── adler32.mbt
│   └── zlib_test.mbt
└── justfile
```

## License

Apache-2.0
