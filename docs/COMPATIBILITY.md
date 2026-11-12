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

`unsloth` and `unsloth-zoo` are not imported in `checks.smoke-cpu`. Both raise
at import time without a GPU ("Unsloth currently only supports GPUs!"), and
nixpkgs sets `dontUsePythonImportsCheck` on them for the same reason. Building
the environment shows that they build. Importing them needs a GPU, which is
what the demo in [apps/demo.py](../apps/demo.py) does on the CUDA environment.

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
`aarch64-linux` is out: the `torchao` dependency marks aarch64 as a bad
platform, and the CUDA and machine-learning stack is x86-only.
