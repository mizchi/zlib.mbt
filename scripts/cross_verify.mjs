#!/usr/bin/env node
// Cross-verification: MoonBit zlib vs Node.js native zlib
import { execSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import zlib from "node:zlib";

const tmpDir = mkdtempSync(join(tmpdir(), "zlib-verify-"));
let passed = 0;
let failed = 0;

function moonRun(mode, format, inputPath, outputPath) {
  const cmd = `moon run --target js src/cmd/verify -- ${mode} ${format} ${inputPath} ${outputPath}`;
  const result = execSync(cmd, { encoding: "utf-8", timeout: 30000 });
  return result.trim();
}

function generateTestData(size, pattern = "sequential") {
  const buf = Buffer.alloc(size);
  for (let i = 0; i < size; i++) {
    switch (pattern) {
      case "sequential":
        buf[i] = i % 256;
        break;
      case "repeated":
        buf[i] = 0x61; // 'a'
        break;
      case "random":
        buf[i] = Math.floor(Math.random() * 256);
        break;
    }
  }
  return buf;
}

function assert(condition, msg) {
  if (!condition) {
    console.error(`  FAIL: ${msg}`);
    failed++;
  } else {
    console.log(`  PASS: ${msg}`);
    passed++;
  }
}

function test(name, fn) {
  console.log(`\n[${name}]`);
  try {
    fn();
  } catch (e) {
    console.error(`  ERROR: ${e.message}`);
    failed++;
  }
}

// --- Tests ---

// 1. Node.js compresses → MoonBit decompresses
test("Node zlib compress → MoonBit decompress (small)", () => {
  const data = Buffer.from("hello world");
  const compressed = zlib.deflateSync(data);
  const zlibCompressed = zlib.deflateSync(data, { level: zlib.constants.Z_DEFAULT_COMPRESSION });
  const zlibWrapped = Buffer.concat([
    Buffer.from([0x78, 0x01]),
    zlibCompressed,
    (() => {
      // Adler32 in big-endian - use zlib's built-in
      return Buffer.alloc(0); // zlib.deflateSync with zlib wrapper includes checksum
    })(),
  ]);
  // Use the full zlib-wrapped format
  const nodeZlib = zlib.deflateSync(data);
  const nodeZlibWrapped = zlib.deflateRawSync(data); // raw deflate

  // Raw deflate: node compress → moonbit decompress
  const inPath = join(tmpDir, "node_deflate_small.bin");
  const outPath = join(tmpDir, "node_deflate_small_out.bin");
  writeFileSync(inPath, nodeZlibWrapped);
  moonRun("decompress", "deflate", inPath, outPath);
  const result = readFileSync(outPath);
  assert(data.equals(result), "deflate roundtrip matches");
});

test("Node zlib compress → MoonBit decompress (zlib format, small)", () => {
  const data = Buffer.from("hello world");
  const compressed = zlib.deflateSync(data); // zlib format (with header)
  const inPath = join(tmpDir, "node_zlib_small.bin");
  const outPath = join(tmpDir, "node_zlib_small_out.bin");
  writeFileSync(inPath, compressed);
  moonRun("decompress", "zlib", inPath, outPath);
  const result = readFileSync(outPath);
  assert(data.equals(result), "zlib roundtrip matches");
});

test("Node gzip compress → MoonBit decompress (small)", () => {
  const data = Buffer.from("hello world");
  const compressed = zlib.gzipSync(data);
  const inPath = join(tmpDir, "node_gzip_small.bin");
  const outPath = join(tmpDir, "node_gzip_small_out.bin");
  writeFileSync(inPath, compressed);
  moonRun("decompress", "gzip", inPath, outPath);
  const result = readFileSync(outPath);
  assert(data.equals(result), "gzip roundtrip matches");
});

// 2. MoonBit compresses → Node.js decompresses
test("MoonBit zlib compress → Node decompress (small)", () => {
  const data = Buffer.from("hello world");
  const inPath = join(tmpDir, "mb_zlib_in.bin");
  const outPath = join(tmpDir, "mb_zlib_out.bin");
  writeFileSync(inPath, data);
  moonRun("compress", "zlib", inPath, outPath);
  const compressed = readFileSync(outPath);
  const result = zlib.inflateSync(compressed);
  assert(data.equals(result), "zlib roundtrip matches");
});

test("MoonBit deflate compress → Node decompress (small)", () => {
  const data = Buffer.from("hello world");
  const inPath = join(tmpDir, "mb_deflate_in.bin");
  const outPath = join(tmpDir, "mb_deflate_out.bin");
  writeFileSync(inPath, data);
  moonRun("compress", "deflate", inPath, outPath);
  const compressed = readFileSync(outPath);
  const result = zlib.inflateRawSync(compressed);
  assert(data.equals(result), "deflate roundtrip matches");
});

test("MoonBit gzip compress → Node decompress (small)", () => {
  const data = Buffer.from("hello world");
  const inPath = join(tmpDir, "mb_gzip_in.bin");
  const outPath = join(tmpDir, "mb_gzip_out.bin");
  writeFileSync(inPath, data);
  moonRun("compress", "gzip", inPath, outPath);
  const compressed = readFileSync(outPath);
  const result = zlib.gunzipSync(compressed);
  assert(data.equals(result), "gzip roundtrip matches");
});

// 3. Larger data tests
for (const [size, label] of [[1024, "1KB"], [65535, "64KB"], [256 * 1024, "256KB"]]) {
  for (const pattern of ["sequential", "repeated"]) {
    test(`Cross-verify zlib ${label} ${pattern}`, () => {
      const data = generateTestData(size, pattern);

      // MoonBit compress → Node decompress
      const inPath = join(tmpDir, `mb_zlib_${label}_${pattern}_in.bin`);
      const outPath = join(tmpDir, `mb_zlib_${label}_${pattern}_out.bin`);
      writeFileSync(inPath, data);
      moonRun("compress", "zlib", inPath, outPath);
      const compressed = readFileSync(outPath);
      const result = zlib.inflateSync(compressed);
      assert(data.equals(result), `MoonBit→Node zlib ${label} ${pattern}`);

      // Node compress → MoonBit decompress
      const nodeCompressed = zlib.deflateSync(data);
      const inPath2 = join(tmpDir, `node_zlib_${label}_${pattern}_in.bin`);
      const outPath2 = join(tmpDir, `node_zlib_${label}_${pattern}_out.bin`);
      writeFileSync(inPath2, nodeCompressed);
      moonRun("decompress", "zlib", inPath2, outPath2);
      const result2 = readFileSync(outPath2);
      assert(data.equals(result2), `Node→MoonBit zlib ${label} ${pattern}`);
    });

    test(`Cross-verify deflate ${label} ${pattern}`, () => {
      const data = generateTestData(size, pattern);

      // MoonBit compress → Node decompress
      const inPath = join(tmpDir, `mb_deflate_${label}_${pattern}_in.bin`);
      const outPath = join(tmpDir, `mb_deflate_${label}_${pattern}_out.bin`);
      writeFileSync(inPath, data);
      moonRun("compress", "deflate", inPath, outPath);
      const compressed = readFileSync(outPath);
      const result = zlib.inflateRawSync(compressed);
      assert(data.equals(result), `MoonBit→Node deflate ${label} ${pattern}`);

      // Node compress → MoonBit decompress
      const nodeCompressed = zlib.deflateRawSync(data);
      const inPath2 = join(tmpDir, `node_deflate_${label}_${pattern}_in.bin`);
      const outPath2 = join(tmpDir, `node_deflate_${label}_${pattern}_out.bin`);
      writeFileSync(inPath2, nodeCompressed);
      moonRun("decompress", "deflate", inPath2, outPath2);
      const result2 = readFileSync(outPath2);
      assert(data.equals(result2), `Node→MoonBit deflate ${label} ${pattern}`);
    });

    test(`Cross-verify gzip ${label} ${pattern}`, () => {
      const data = generateTestData(size, pattern);

      // MoonBit compress → Node decompress
      const inPath = join(tmpDir, `mb_gzip_${label}_${pattern}_in.bin`);
      const outPath = join(tmpDir, `mb_gzip_${label}_${pattern}_out.bin`);
      writeFileSync(inPath, data);
      moonRun("compress", "gzip", inPath, outPath);
      const compressed = readFileSync(outPath);
      const result = zlib.gunzipSync(compressed);
      assert(data.equals(result), `MoonBit→Node gzip ${label} ${pattern}`);

      // Node compress → MoonBit decompress
      const nodeCompressed = zlib.gzipSync(data);
      const inPath2 = join(tmpDir, `node_gzip_${label}_${pattern}_in.bin`);
      const outPath2 = join(tmpDir, `node_gzip_${label}_${pattern}_out.bin`);
      writeFileSync(inPath2, nodeCompressed);
      moonRun("decompress", "gzip", inPath2, outPath2);
      const result2 = readFileSync(outPath2);
      assert(data.equals(result2), `Node→MoonBit gzip ${label} ${pattern}`);
    });
  }
}

// Cleanup
rmSync(tmpDir, { recursive: true });

console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
process.exit(failed > 0 ? 1 : 0);
