# Design: Bzlmod-only + Bazel 9.1.0 Support

## Summary

Drop WORKSPACE mode entirely from rules_haskell, making it bzlmod-only, and add support for Bazel 9.1.0. These two changes are done together because Bazel 9 disables WORKSPACE by default, making the bzlmod-only migration natural.

## Section 1: Core dependency infrastructure

### Changes to `haskell/private/versions.bzl`
- Remove `SUPPORTED_BAZEL_VERSIONS` (no longer needed; replaced by `bazel_compatibility` in MODULE.bazel)
- Remove `SUPPORTED_NIXPKGS_BAZEL_PACKAGES` (no longer needed)
- Remove `_parse_bazel_version()` (no callers remain)
- Remove `check_bazel_version_compatible()` (no callers remain)
- Keep `is_at_least()`, `is_at_most()`, `check_bazel_version()` — still used for feature guards in `cabal.bzl` and `ghc_bindist.bzl`

### Changes to `MODULE.bazel`
- Add `bazel_compatibility = ["^6", "^7", "^8", "^9"]`

### Removed files
- `WORKSPACE` (root, tests, examples, tutorial, nix, arm)
- All nested test WORKSPACE files (~10 files)
- All `WORKSPACE.bzlmod` empty files
- `haskell/repositories.bzl` — its only purpose was WORKSPACE dependency loading + version check

### Changes to `haskell/repositories.bzl`
- Delete the file entirely
- Update any `load()` references across the codebase to point elsewhere if needed
- `rules_haskell_dependencies_bzlmod()` (from `extensions/rules_haskell_dependencies.bzl`) becomes the canonical initialization path, rename to `rules_haskell_dependencies()`

## Section 2: Simplify shared dependency functions

### `non_module_dev_deps.bzl` (root)
- Remove `bzlmod` parameter
- Remove WORKSPACE-mode `nixpkgs_local_repository`, `nixpkgs_package` calls (glibc_locales, zip, graphviz, doxygen, sphinx, pandoc, etc.)
- Remove `nixpkgs_cc_configure`, `nixpkgs_python_configure`, `nixpkgs_go_configure`
- Keep only the module extension `non_module_dev_deps`
- Stardoc Maven deps move to `use_extension(@rules_jvm_external//:extensions.bzl, "maven")` in MODULE.bazel

### `rules_haskell_tests/non_module_deps.bzl`
- Remove `bzlmod` parameter and WORKSPACE paths for os_info, c2hs_repo, library_repo, zlib.hs, buildtools, runfiles_repo
- Keep only the module extension

### `rules_haskell_tests/non_module_deps_1.bzl`
- Remove `bzlmod` parameter and WORKSPACE paths for nixpkgs, CC, Python, Go, asterius, zlib, bazel binaries, glibc_locales
- Keep only the module extension; add `bazel_binaries` entries for Bazel 9.x

### `rules_haskell_tests/non_module_deps_2.bzl`
- Remove `bzlmod` parameter and WORKSPACE paths for stackage-zlib, ghcide, alex, Cabal, stackage-pinning-test, stackage_asterius
- Keep only the module extension

### `.bazelrc.bzlmod`
- Delete entirely
- Merge `--enable_bzlmod` and `--registry` settings into `.bazelrc.common` (or remove `--enable_bzlmod` since it's default in Bazel 8+)
- Remove `--noenable_bzlmod` line

## Section 3: Remove WORKSPACE-only code guards

### `haskell/cabal.bzl`
- Remove `_is_bzlmod_enabled()` — always returns True
- Simplify `_label_to_string()`: always use `str(label)`, remove `check_bazel_version("6.0.0")` guard
- Remove all `if _is_bzlmod_enabled(): prefix = "@@"` branches, always use `@@` prefix

### `rules_haskell_nix/nixpkgs.bzl`
- Remove `_is_bzlmod_enabled()` — always returns True
- Simplify label string generation to always use `@@` prefix

### `bind(name = "python_headers")`
- Remove from WORKSPACE. If profiling needs this, find alternative in bzlmod or drop the profiling hack.

### `haskell/private/haskell_impl.bzl`
- The `hasattr(ctx, "resolve_tools")` guard stays (Bazel 9 removed the API)
- `ctx.workspace_name` references stay (works in bzlmod)

## Section 4: CI and test infrastructure

### `.github/workflows/workflow.yaml`
- Remove `bzlmod` from the matrix (now the only mode)
- Remove `common --enable_bzlmod=${{ matrix.bzlmod }}` from all jobs
- Add Bazel `9.x` to the `examples-bindist` matrix
- Remove Windows + Bazel 7 exclusion (was a TODO to add full support)

### `.bazelci/presubmit.yml`
- Remove `--enable_workspace` conditional for non-6.x Bazel
- Add `9.x` to the matrix

### `.bcr/presubmit.yml`
- Add `9.x` to the matrix

### Integration test nested WORKSPACE files
- Convert each of the ~10 nested test workspaces to use MODULE.bazel only
- Delete tests that only tested WORKSPACE-specific behavior
- Update `rules_haskell_integration_test.bzl` to always use bzlmod mode

### `rules_haskell_tests/tests/integration_testing/dependencies.bzl`
- Add Bazel 9.x binary distribution entries
- Add `bazel_9` nixpkgs package

### `rules_haskell_tests/non_module_deps_1.bzl`
- Add `build_bazel_bazel_9_1_0` binary and `bazel_9` nixpkgs entries

### `shell.nix` and `rules_haskell_tests/shell.nix`
- Add `bazel_9` as an option alongside `bazel_6`

## Section 5: Start script and documentation

### `start` script
- Remove `--with-bzlmod` flag (always on)
- Remove WORKSPACE generation path
- Generate only MODULE.bazel-based projects
- Update `MAX_BAZEL_MAJOR`/`MAX_BAZEL_MINOR` to cover 9.x
- Remove Bazel version range check (replaced by `bazel_compatibility`)

### `README.md`
- Update Bazel version requirement to ">= 6.0 (bzlmod required)"
- Remove Bazel 8 `--noincompatible_disallow_ctx_resolve_tools` note

### `tutorial/.bazeliskrc`
- Update `USE_BAZEL_VERSION` if needed

### `.bazelversion`
- Update to 9.1.0 (or keep as 6.5.0 with bazel_compatibility guarding)

## Risks

- Breaking change for any downstream WORKSPACE users
- Integration test conversion is the highest-effort item (~10 nested workspaces)
- `python_headers` bind hack needs investigation for profiling support
- Nixpkgs must have `bazel_9` package available (may need nixpkgs bump)
