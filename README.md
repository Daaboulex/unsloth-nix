# unsloth-nix

<!-- BEGIN generated:badges -->
[![CI](https://github.com/Daaboulex/unsloth-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/unsloth-nix/actions/workflows/ci.yml)
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
<!-- END generated:badges -->

[Unsloth](https://github.com/unslothai/unsloth) — finetune LLMs 2× faster with ~70% less memory — packaged as a Nix flake. Tracks `unsloth` + `unsloth-zoo` from **git main** (always latest) glued onto nixpkgs' cached PyTorch / Transformers / PEFT / TRL stack (robust, substituted, never forked). Ships ready-to-deploy **CPU**, **CUDA**, and **ROCm** Python environments, dev shells, a NixOS module, and a runnable demo.

<!-- BEGIN generated:upstream -->
## Upstream

| | |
|---|---|
| **Project** | <https://github.com/unslothai/unsloth> (+ [unsloth-zoo](https://github.com/unslothai/unsloth-zoo)) |
| **License** | unsloth: Apache-2.0 · unsloth-zoo: LGPL-3.0-or-later (this packaging: MIT) |
| **Tracked** | Git HEAD (`main`) of both repos |

The pinned commits, source hashes, and versions are the single source of truth
in [`version.json`](./version.json). The daily `update.yml` workflow runs the
custom [`scripts/update.sh`](./scripts/update.sh), which re-pins both repos and
commits the bump to `main`.
<!-- END generated:upstream -->

## Why?

`nixpkgs` ships `python3Packages.unsloth`, but it tracks the PyPI release and
lags upstream by weeks — and Unsloth iterates fast (new model support, kernels,
and bug fixes land on `main` constantly). This flake follows `main` for the two
small, pure-Python Unsloth packages while inheriting the *entire* heavy
dependency stack (torch, xformers, bitsandbytes, triton, transformers, …)
unchanged from nixpkgs. You get the latest Unsloth on a robust, cache-backed
foundation, with three accelerator targets and the full CI + auto-update
contract of the [Daaboulex Nix Packaging Standard](https://github.com/Daaboulex/nix-packaging-standard).

## Outputs

| Output | What |
|---|---|
| `packages.default` / `packages.cuda` | CUDA Python env (primary; NVIDIA GPU) |
| `packages.cpu` | CPU Python env (cache-backed; built in CI) |
| `packages.rocm` | ROCm Python env (AMD GPU; experimental — see below) |
| `devShells.{default,cpu,rocm}` | env + lint hooks (`default` adds Jupyter) |
| `apps.default` | `unsloth-demo` — assert CUDA + print the stack |
| `overlays.default` | git-main `unsloth`/`unsloth-zoo` override for your own nixpkgs |
| `nixosModules.default` | `programs.unsloth.enable` — install an env system-wide |

<!-- BEGIN generated:installation -->
## Installation

Run the CUDA demo (NVIDIA host), or build an env directly:

```bash
nix run github:Daaboulex/unsloth-nix             # CUDA demo: assert GPU + print stack
nix build github:Daaboulex/unsloth-nix#cpu       # CPU env
nix build github:Daaboulex/unsloth-nix#cuda      # CUDA env (NVIDIA)
nix build github:Daaboulex/unsloth-nix#rocm      # ROCm env (AMD, experimental)
nix develop github:Daaboulex/unsloth-nix         # CUDA dev shell + Jupyter
```

As a flake input with the NixOS module:

```nix
{
  inputs.unsloth-nix.url = "github:Daaboulex/unsloth-nix";

  # in your host config:
  imports = [ inputs.unsloth-nix.nixosModules.default ];
  nixpkgs.overlays = [ inputs.unsloth-nix.overlays.default ];
  nixpkgs.config = { allowUnfree = true; cudaSupport = true; };
  programs.unsloth = { enable = true; accelerator = "cuda"; };
}
```

<!-- END generated:installation -->

## Building the GPU envs (off-CI)

CUDA/ROCm PyTorch is **not** on `cache.nixos.org`, so the CUDA and ROCm envs
are not built in CI (CI builds and verifies only the CPU env and eval-gates the
GPU envs). Build them on a machine configured with the community GPU cache so
you don't compile torch from source. Add the cache once (it installs the
correct signing key for you):

```bash
cachix use cuda-maintainers          # CUDA artifacts
cachix use nixos-rocm                # ROCm artifacts (AMD)

nix build github:Daaboulex/unsloth-nix#cuda
nix build github:Daaboulex/unsloth-nix#rocm
```

Or pass the substituter inline for a one-off CUDA build:

```bash
nix build github:Daaboulex/unsloth-nix#cuda \
  --extra-substituters https://cuda-maintainers.cachix.org \
  --extra-trusted-public-keys cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=
```

> **ROCm is experimental.** Unsloth's hard dependencies (`xformers`,
> `bitsandbytes`) are CUDA-centric and AMD/ROCm support across the stack is
> still maturing in nixpkgs, so the `rocm` env may fail to evaluate on a given
> `nixpkgs` pin. The `rocm-eval` CI gate reports this honestly rather than
> hiding it.

## Development

```bash
nix develop                  # dev shell + pre-commit hooks
nix fmt                      # format
nix flake check              # eval-gates + std-conformance + schema (no heavy build)
nix flake show               # confirm outputs
```

`nix flake check` is fast: it evaluates the CUDA/ROCm envs (catching breakage)
but only *builds* the cache-backed CPU env.

## Repository Structure

```text
unsloth-nix/
├── flake.nix          # outputs: envs (cpu/cuda/rocm), overlay, module, app, checks
├── lib.nix            # shared env builder (one overlay, three accelerator pkgs sets)
├── overlay.nix        # pythonPackagesExtensions: git-main unsloth + unsloth-zoo
├── module.nix         # nixosModules.default — programs.unsloth
├── version.json       # pinned revs + hashes + versions (source of truth)
├── apps/demo.py       # apps.default — unsloth-demo
├── scripts/update.sh  # custom updater: re-pin both git srcs
├── LICENSE            # MIT (packaging glue)
└── README.md
```

## License

This packaging flake is [MIT](./LICENSE). Upstream `unsloth` is Apache-2.0 and
`unsloth-zoo` is LGPL-3.0-or-later; their `meta.license` is preserved as
shipped by nixpkgs.

<!-- BEGIN generated:footer -->
---

*Maintained as part of the [Daaboulex](https://github.com/Daaboulex) NixOS ecosystem.*
<!-- END generated:footer -->
