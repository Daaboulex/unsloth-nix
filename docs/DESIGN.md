# Design

Why the packaging is built the way it is. The [README](../README.md) says how
to use it.

## Why it follows main

`nixpkgs` ships `python3Packages.unsloth`, but it tracks the PyPI release and
lags upstream by weeks, and Unsloth iterates fast: new model support, kernels
and bug fixes land on `main` constantly. This flake follows `main` for the two
pure-Python Unsloth packages and takes the rest of the dependency stack (torch,
xformers, bitsandbytes, triton, transformers and the others) from nixpkgs. It
has three accelerator targets and follows the
[Nix Packaging Standard](https://github.com/Daaboulex/nix-packaging-standard)
for CI and updates.

## Upstream

| | |
|---|---|
| Project | <https://github.com/unslothai/unsloth> and [unsloth-zoo](https://github.com/unslothai/unsloth-zoo) |
| License | unsloth: Apache-2.0. unsloth-zoo: LGPL-3.0-or-later. This packaging: MIT |
| Tracked | Git HEAD (`main`) of both repositories |

The pinned commits, source hashes and versions are the single source of truth
in [version.json](../version.json).

## What differs from nixpkgs

Three things differ from the nixpkgs packages.

`accelerate` is rebuilt with its tests off, so it and every package that
depends on it build from source. The packages that do not depend on it are the
unchanged nixpkgs builds. Its test suite is flaky inside the Nix build sandbox:
multi-process Gloo races in two CUDA environment builds on 2026-06-10, and a
numerically fragile gradient-sync assertion in `test_sync.py` on 2026-06-18.
None of `accelerate`'s code is changed.

`unsloth-zoo` gains `einops` and `unsloth` gains `json5` as dependencies.

`overlays.default` also applies the temporary nixpkgs fixes in
[overlays/](../overlays/).

## How the two packages are overridden

[overlay.nix](../overlay.nix) overrides `unsloth` and `unsloth-zoo` through
`pythonPackagesExtensions`, so the override reaches every Python the consuming
nixpkgs builds, at any accelerator configuration.

It replaces the source, the version and the version setuptools-scm is told,
because a GitHub tarball carries neither `PKG-INFO` nor `.git` to infer one
from. It relaxes the pins `main` moves ahead of nixpkgs and skips the build's
dependency check. The `meta` of both packages, their license included, is
inherited from nixpkgs.

nixpkgs' `dont-require-unsloth.patch` for `unsloth-zoo` is cut against the PyPI
release and does not apply to `main`. The overlay drops it and makes the same
change with a substitution that does not depend on position or indentation.

nixpkgs' own `postPatch` is kept, with its build-system unpin made quiet, since
`main` moves those pins. The overlay fails to evaluate, with a message, the day
nixpkgs stops unpinning that way.

## One builder, three nixpkgs

[lib.nix](../lib.nix) builds the three environments from one overlay and three
nixpkgs instances that differ only by the accelerator flag: none for `cpu`,
`cudaSupport` for `cuda`, `rocmSupport` for `rocm`. The packages, the checks,
the dev shells and the demo all take their environments from it, so the build
targets and the evaluation checks cannot diverge.

Each of the three instances sets `allowUnfree`.

## Outputs

| Output | What |
|---|---|
| `packages.default`, `packages.cuda` | CUDA Python environment (primary, NVIDIA GPU) |
| `packages.cpu` | CPU Python environment, built in CI: `unsloth`, `unsloth-zoo`, `accelerate` and the packages that depend on it build from source, the rest is substituted from `cache.nixos.org` |
| `packages.rocm` | ROCm Python environment (AMD GPU, experimental, see [COMPATIBILITY.md](COMPATIBILITY.md)) |
| `devShells.default`, `devShells.cpu`, `devShells.rocm` | the environment and the lint hooks. `default` is the CUDA one and adds Jupyter |
| `apps.default` | `unsloth-demo`: assert CUDA and print the stack |
| `overlays.default` | the `main` override of `unsloth` and `unsloth-zoo` for your own nixpkgs, plus the temporary nixpkgs fixes |
| `overlays.probe` | the same override without the temporary nixpkgs fixes |
| `nixosModules.default` | `programs.unsloth.enable`: install an environment system-wide |

Only `cpu` is declared where the standard turns a package into a built check.
`cuda`, `rocm` and `default` are declared on the raw package surface instead,
which keeps them as build targets without making CI realize their uncached GPU
closures.

## The module

[module.nix](../module.nix) builds the environment from the host's nixpkgs, so
the host applies `overlays.default` and sets the accelerator's flag on its own
nixpkgs. `accelerator` does not choose the build. It states what the host
expects, and two assertions compare it with the nixpkgs configuration, so a CPU
torch is never shipped under a `cuda` label.

## Temporary fixes

A temporary nixpkgs fix is one file under [overlays/](../overlays/) holding a
`meta`, a `dropWhen` and an `overlay`. `overlays.default` is the override plus
those fixes. `overlays.probe` is the override alone: the standard's maintenance
run tests each `dropWhen` against it and deletes a fix once it is no longer
needed.

Every environment is built from `unslothPython`, which the overlay sets to
`python3`. A temporary fix can repoint the whole stack at another interpreter
there.

## The GPU caches are not in the flake

The caches that carry CUDA and ROCm PyTorch are configured by the user, not by
a `nixConfig` block in `flake.nix`. Such a block prints an "ignoring untrusted
flake configuration" warning on every command, and CI ignores it anyway.
