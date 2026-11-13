#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { cpus, homedir, platform, release } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const target = process.argv[2] ?? "native";
const imported = process.argv[3] === "--import-jsonl" ? process.argv[4] : undefined;
if (!["native", "js", "wasm", "wasm-gc"].includes(target) ||
    (process.argv.length > 3 && (!imported || process.argv.length !== 5))) {
  throw new Error("Usage: node scripts/bench_core.mjs [native|js|wasm|wasm-gc] [--import-jsonl FILE]");
}
const output = join(root, "benchmarks/results");
mkdirSync(output, { recursive: true });
const command = ["run", "src/core_compare", "--target", target, "--release"];
const capture = (cmd, args) => execFileSync(cmd, args, { cwd: root, encoding: "utf8" }).trim();
// Identify the core sources actually used, independently of a checkout's HEAD.
const moonHome = process.env.MOON_HOME ?? join(homedir(), ".moon");
const core = join(moonHome, "lib/core");
const coreHashes = {};
for (const pkg of ["compress/flate", "compress/zlib", "compress/gzip", "internal/checksum"]) {
  const hash = createHash("sha256");
  for (const file of readdirSync(join(core, pkg)).sort()) {
    if (!file.endsWith(".mbt") || /_(?:wb)?test\.mbt$/.test(file)) continue;
    hash.update(`${pkg}/${file}`);
    hash.update(readFileSync(join(core, pkg, file)));
  }
  coreHashes[pkg] = hash.digest("hex");
}
const metadata = {
  measured_at: imported ? statSync(imported).mtime.toISOString() : new Date().toISOString(),
  target,
  command: ["moon", ...command],
  toolchain: capture("moon", ["version", "--all"]),
  node: process.version,
  os: `${platform()} ${release()}`,
  cpu: cpus()[0].model,
  zlib_revision: capture("git", ["rev-parse", "HEAD"]),
  working_tree: capture("git", ["status", "--short"]),
  core_source_sha256: coreHashes,
  timing: "microseconds per operation; 5 calibrated batches; median; process startup and input generation excluded",
};
const prefix = join(output, `core-compare-${target}`);
writeFileSync(`${prefix}.metadata.json`, `${JSON.stringify(metadata, null, 2)}\n`);
console.error(`${imported ? "Importing" : "Measuring"} ${target}; results: ${prefix}.jsonl`);
const stdout = imported ? readFileSync(imported, "utf8") : execFileSync("moon", command, {
  cwd: root,
  encoding: "utf8",
  timeout: 1_800_000,
  maxBuffer: 16 * 1024 * 1024,
  stdio: ["ignore", "pipe", "inherit"],
});
const rows = stdout.trim().split("\n").map(line => JSON.parse(line));
if (rows.length !== 72) throw new Error(`Expected 72 measurements, received ${rows.length}`);
writeFileSync(`${prefix}.jsonl`, `${rows.map(row => JSON.stringify(row)).join("\n")}\n`);
const csv = ["operation,format,kind,input_bytes,implementation,compressed_bytes,median_us,std_dev_pct"];
for (const row of rows) {
  csv.push([row.operation, row.format, row.kind, row.input_bytes, row.implementation,
    row.compressed_bytes, row.summary.median, row.summary.std_dev_pct].join(","));
}
writeFileSync(`${prefix}.csv`, `${csv.join("\n")}\n`);
console.error(`Saved ${rows.length} measurements and metadata.`);
