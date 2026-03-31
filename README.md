# mk-pnpm-cli — Multi-install-root restore fails on overlapping paths

When two install roots have overlapping paths (root deps stage external install root manifests, then the external install root restore writes into the same directories), the second `cp -a` restore fails because the first restore preserved read-only Nix store permissions on directories.

## Reproduction

```bash
bash repro.sh
```

## Expected

Both install root restores complete successfully.

## Actual

The second restore fails with "Permission denied" because `cp -a` from the first restore set directories to read-only (Nix store permissions):

```
=== Restore 1: root deps (cp -a root-deps/. workspace/) ===
OK: root restore succeeded

=== Directory permissions after root restore ===
dr-xr-xr-x  repos/effect-utils/

=== Restore 2: effect-utils deps (cp -a eu-deps/. workspace/) ===
cp: cannot create directory 'workspace/./repos/effect-utils/node_modules': Permission denied
```

## Fix

Add `chmod -R +w workspace` between install root restores in `mk-pnpm-cli.nix` (~line 787):

```bash
bash repro-with-fix.sh  # demonstrates the fix works
```

The fix is a one-line addition between the `mkRestoreScript` calls in the build phase:

```nix
# mk-pnpm-cli.nix, buildPhase (around line 780-790)
${builtins.concatStringsSep "\nchmod -R +w workspace\n" (
  map (root: pnpmDepsHelper.mkRestoreScript { ... }) depsInstallRoots
)}
chmod -R +w workspace
```

## Context

This occurs in `megarepo-all` (schickling/megarepo-all#62) where:
- Root `pnpm-workspace.yaml` lists `repos/effect-utils/packages/*` as workspace members via `extraMembers`
- `mk-pnpm-cli` stages external install root manifests (repos/effect-utils/) into the root deps src for link resolution
- The root deps FOD output includes `repos/effect-utils/` directory tree with read-only perms
- The effect-utils install root restore tries to create `node_modules` under the same paths

Dotfiles (schickling/dotfiles#484) avoids this because its root workspace members (`flakes/*`) don't overlap with `repos/effect-utils/`.

## Versions

- effect-utils: `88f3627` (main, 2026-03-31)
- GNU coreutils cp: 9.9 (Nix)
- OS: macOS 15.3.2 (Darwin 25.2.0) — also affects Linux (same GNU cp behavior)

## Related Issue

TBD
