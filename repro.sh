#!/usr/bin/env bash
set -euo pipefail

# Reproduces the multi-install-root restore overlap in mk-pnpm-cli.
#
# mk-pnpm-cli restores prepared deps for each install root via `cp -a`.
# When the root deps include manifests under an external install root
# (e.g. repos/effect-utils/package.json), `cp -a` preserves read-only
# Nix store permissions on directories, preventing subsequent restores
# from writing into the same paths.
#
# This is the same sequence as mk-pnpm-cli.nix lines 776-790:
#   1. cp -r workspace-snapshot workspace   (source copy)
#   2. chmod -R +w workspace                (make writable)
#   3. cp -a root-deps/. workspace/         (restore root deps — sets dirs read-only)
#   4. cp -a eu-deps/. workspace/           (restore effect-utils deps — FAILS)
#   5. chmod -R +w workspace                (never reached)

cleanup() { rm -rf "$WORK"; }
WORK=$(mktemp -d)
trap cleanup EXIT

echo "=== Setup ==="

# Simulate workspace snapshot (from workspaceClosureSrc copy)
mkdir -p "$WORK/workspace/repos/effect-utils/packages/@overeng/tui-core"
echo '{"name":"tui-core"}' > "$WORK/workspace/repos/effect-utils/packages/@overeng/tui-core/package.json"
echo '{"name":"effect-utils"}' > "$WORK/workspace/repos/effect-utils/package.json"
echo "packages: [packages/@overeng/tui-core]" > "$WORK/workspace/repos/effect-utils/pnpm-workspace.yaml"
mkdir -p "$WORK/workspace/tools/alignment-cli"
echo '{"name":"alignment-cli"}' > "$WORK/workspace/tools/alignment-cli/package.json"

# Make writable (simulates chmod -R +w workspace after workspace copy)
chmod -R +w "$WORK/workspace"

# Simulate root deps build (FOD output from mkDeps for "." install root)
# Root deps stage external install root manifests for link resolution
mkdir -p "$WORK/root-deps/repos/effect-utils/packages/@overeng/tui-core"
echo '{"name":"tui-core"}' > "$WORK/root-deps/repos/effect-utils/packages/@overeng/tui-core/package.json"
echo '{"name":"effect-utils"}' > "$WORK/root-deps/repos/effect-utils/package.json"
echo "packages: [packages/@overeng/tui-core]" > "$WORK/root-deps/repos/effect-utils/pnpm-workspace.yaml"
mkdir -p "$WORK/root-deps/node_modules/.pnpm"
echo "root-dep" > "$WORK/root-deps/node_modules/.pnpm/placeholder"

# Make root deps read-only (simulates Nix store permissions)
chmod -R a-w "$WORK/root-deps"

# Simulate effect-utils deps build (FOD output from mkDeps for "repos/effect-utils" install root)
mkdir -p "$WORK/eu-deps/repos/effect-utils/node_modules/.pnpm"
echo "eu-dep" > "$WORK/eu-deps/repos/effect-utils/node_modules/.pnpm/placeholder"
mkdir -p "$WORK/eu-deps/repos/effect-utils/packages/@overeng/tui-core/node_modules/.pnpm"
echo "tui-core-dep" > "$WORK/eu-deps/repos/effect-utils/packages/@overeng/tui-core/node_modules/.pnpm/placeholder"

# Make effect-utils deps read-only (simulates Nix store permissions)
chmod -R a-w "$WORK/eu-deps"

echo "=== Restore 1: root deps (cp -a root-deps/. workspace/) ==="
# This is mkRestoreScript for the "." install root
if cp -a "$WORK/root-deps"/. "$WORK/workspace"/; then
  echo "OK: root restore succeeded"
else
  echo "FAIL: root restore failed (exit $?)"
  exit 1
fi

echo ""
echo "=== Directory permissions after root restore ==="
ls -la "$WORK/workspace/repos/effect-utils/"
echo ""

echo "=== Restore 2: effect-utils deps (cp -a eu-deps/. workspace/) ==="
# This is mkRestoreScript for the "repos/effect-utils" install root
if cp -a "$WORK/eu-deps"/. "$WORK/workspace"/ 2>&1; then
  echo "OK: effect-utils restore succeeded"
else
  echo ""
  echo "FAIL: effect-utils restore failed!"
  echo ""
  echo "The root restore's cp -a set repos/effect-utils/ directory to read-only"
  echo "(preserving Nix store permissions). The effect-utils restore cannot write"
  echo "into it. This is the mk-pnpm-cli bug."
  echo ""
  echo "Fix: add 'chmod -R +w workspace' between install root restores"
  echo "     (mk-pnpm-cli.nix, between the mkRestoreScript calls at ~line 787)"
  exit 1
fi

echo ""
echo "=== chmod -R +w workspace (would run here, but too late) ==="
chmod -R +w "$WORK/workspace"
echo "All good after chmod."
