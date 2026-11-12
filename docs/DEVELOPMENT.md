# Development

```bash
nix develop
nix fmt
nix flake check
nix flake show
```

`nix develop` opens the dev shell with the pre-commit hooks. The default shell
carries the CUDA environment and Jupyter. `nix develop .#cpu` and
`nix develop .#rocm` carry the CPU and ROCm environments instead.

`nix fmt` formats. `nix flake show` confirms the outputs.

`nix flake check` runs the evaluation checks, the standard's conformance check
and the schema check, with no heavy build. It evaluates the CUDA and ROCm
environments and builds only the CPU environment. In that build `unsloth`,
`unsloth-zoo`, `accelerate` and the packages that depend on it build from
source. The rest is substituted from `cache.nixos.org`.

What each check covers is in [COMPATIBILITY.md](COMPATIBILITY.md).

## Building the GPU environments

CUDA and ROCm PyTorch are not on `cache.nixos.org`, so the CUDA and ROCm
environments are not built in CI. Build the CUDA one on a machine that has the
nixos-cuda cache configured (the README shows the two settings), so you do
not compile torch from source. There is no cache to recommend for ROCm.

```bash
nix build github:Daaboulex/unsloth-nix#cuda
nix build github:Daaboulex/unsloth-nix#rocm
```

Or pass the substituter inline for a one-off CUDA build:

```bash
nix build github:Daaboulex/unsloth-nix#cuda \
  --extra-substituters https://cache.nixos-cuda.org \
  --extra-trusted-public-keys cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=
```

## The demo

`nix run` starts `unsloth-demo` through the CUDA environment's interpreter. It
prints the version of every component and asserts that torch sees an NVIDIA
GPU. Without one it exits with an error.

The training step is off by default, so `nix run` works on any NVIDIA host
without pulling a model from Hugging Face. `UNSLOTH_DEMO_TRAIN=1` turns it on:
the demo loads a small model in 4-bit and attaches LoRA adapters.
`UNSLOTH_DEMO_MODEL` names another model than the default,
`unsloth/Qwen2.5-0.5B`.

## Updates

The daily [update.yml](../.github/workflows/update.yml) workflow runs the
custom [scripts/update.sh](../scripts/update.sh), which re-pins both
repositories in [version.json](../version.json) and commits the bump to `main`.

The script is custom because the standard's updater drives one source, and this
flake has two, each with its own commit and hash. After a bump it runs
`nix flake check` and `nix build .#cpu`, and a failure of either stops the
update.

A new dependency pin upstream shows up as a failure of that CPU build. It is
then added to [overlay.nix](../overlay.nix).
