# Compatibility

What is checked for each environment, and by which check in
[flake.nix](../flake.nix). Nothing in CI runs on a GPU.

| Target | What CI does | Check |
|---|---|---|
| `cpu` | builds the environment, then imports `torch`, `transformers`, `datasets`, `accelerate`, `peft` and `trl` with its interpreter | `checks.smoke-cpu` |
| `cuda` | evaluates the full build graph, builds nothing | `checks.cuda-eval` |
| `rocm` | evaluates the full build graph, builds nothing | `checks.rocm-eval` |
| NixOS module | instantiates it with `accelerator = "cpu"` | `checks.module-eval-nixos` |

## What the CPU check leaves out

`checks.smoke-cpu` does not import `unsloth` or `unsloth-zoo`. Their own builds
do: the import check nixpkgs runs on both imports them without a GPU, and
Unsloth falls back to its CPU backend. Nothing in CI trains a model. The demo in
[apps/demo.py](../apps/demo.py) runs on the CUDA environment and needs a GPU.

## CUDA and ROCm

CUDA and ROCm PyTorch are not on `cache.nixos.org`, so the CUDA and ROCm
environments are not built in CI. CI builds and verifies only the CPU
environment and evaluates the GPU ones, which catches a broken dependency,
version or accelerator setting without building the uncached PyTorch.

ROCm is experimental. Unsloth's hard dependencies (`xformers`, `bitsandbytes`)
are CUDA-centric and AMD/ROCm support across the stack is still maturing in
nixpkgs, so the `rocm` environment may fail to evaluate on a given nixpkgs pin.
The `rocm-eval` check fails when that happens.

## Platforms

The flake declares `x86_64-linux` alone. `.github/update.json` records why
`aarch64-linux` is out: `unsloth-zoo` depends on `torchao`, which nixpkgs
marks as a bad platform on aarch64.
