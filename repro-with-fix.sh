#!/usr/bin/env bash
set -euo pipefail

# Same as repro.sh but with the fix: chmod -R +w between restores

cleanup() { rm -rf "$WORK"; }
WORK=$(mktemp -d)
trap cleanup EXIT

# Setup (same as repro.sh)
mkdir -p "$WORK/workspace/repos/effect-utils/packages/@overeng/tui-core"
echo '{"name":"tui-core"}' > "$WORK/workspace/repos/effect-utils/packages/@overeng/tui-core/package.json"
echo '{"name":"effect-utils"}' > "$WORK/workspace/repos/effect-utils/package.json"
echo "packages: [packages/@overeng/tui-core]" > "$WORK/workspace/repos/effect-utils/pnpm-workspace.yaml"
mkdir -p "$WORK/workspace/tools/alignment-cli"
echo '{"name":"alignment-cli"}' > "$WORK/workspace/tools/alignment-cli/package.json"
chmod -R +w "$WORK/workspace"

mkdir -p "$WORK/root-deps/repos/effect-utils/packages/@overeng/tui-core"
echo '{"name":"tui-core"}' > "$WORK/root-deps/repos/effect-utils/packages/@overeng/tui-core/package.json"
echo '{"name":"effect-utils"}' > "$WORK/root-deps/repos/effect-utils/package.json"
echo "packages: [packages/@overeng/tui-core]" > "$WORK/root-deps/repos/effect-utils/pnpm-workspace.yaml"
mkdir -p "$WORK/root-deps/node_modules/.pnpm"
echo "root-dep" > "$WORK/root-deps/node_modules/.pnpm/placeholder"
chmod -R a-w "$WORK/root-deps"

mkdir -p "$WORK/eu-deps/repos/effect-utils/node_modules/.pnpm"
echo "eu-dep" > "$WORK/eu-deps/repos/effect-utils/node_modules/.pnpm/placeholder"
mkdir -p "$WORK/eu-deps/repos/effect-utils/packages/@overeng/tui-core/node_modules/.pnpm"
echo "tui-core-dep" > "$WORK/eu-deps/repos/effect-utils/packages/@overeng/tui-core/node_modules/.pnpm/placeholder"
chmod -R a-w "$WORK/eu-deps"

echo "=== Restore 1: root deps ==="
cp -a "$WORK/root-deps"/. "$WORK/workspace"/
echo "OK"

echo "=== FIX: chmod -R +w workspace between restores ==="
chmod -R +w "$WORK/workspace"

echo "=== Restore 2: effect-utils deps ==="
cp -a "$WORK/eu-deps"/. "$WORK/workspace"/
echo "OK"

echo ""
echo "Both restores succeeded with chmod between them."
