# unsloth-nix

[Unsloth](https://github.com/unslothai/unsloth), a library for fine-tuning
LLMs, packaged as a Nix flake. It follows the `main` branch of `unsloth` and
[`unsloth-zoo`](https://github.com/unslothai/unsloth-zoo) and takes the rest of
the stack, PyTorch, Transformers, PEFT and TRL among it, from nixpkgs. It is
for people who want a newer Unsloth than `python3Packages.unsloth` in nixpkgs,
which tracks the PyPI release.

It builds for `x86_64-linux` only. CI builds the CPU environment and imports
its libraries, all but Unsloth itself, which refuses to load without a GPU.
The CUDA and ROCm environments are only evaluated there, never built or run.
ROCm is experimental.

## What you get

- Three Python environments: `cuda` for NVIDIA GPUs, which is also the default
  package, `rocm` for AMD GPUs and `cpu`.
- A NixOS module, `programs.unsloth`, that installs an environment system-wide.
- A demo, `unsloth-demo`, that checks for a GPU and prints the version of each
  library.
- An overlay that puts the `main` builds of `unsloth` and `unsloth-zoo` into
  your own nixpkgs.

Each environment is a Python interpreter with `unsloth`, `unsloth-zoo`,
`torch`, `transformers`, `peft`, `trl`, `datasets`, `accelerate` and IPython.
The full list is in [lib.nix](lib.nix).

## Install

Add the flake:

```nix
{
  inputs.unsloth-nix.url = "github:Daaboulex/unsloth-nix";
}
```

Then import the module, apply the overlay and switch it on. This is the
configuration for an NVIDIA machine. CUDA is unfree.

```nix
{
  imports = [ inputs.unsloth-nix.nixosModules.default ];
  nixpkgs.overlays = [ inputs.unsloth-nix.overlays.default ];
  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
  };

  programs.unsloth = {
    enable = true;
    accelerator = "cuda";
  };
}
```

The module builds the environment from your own nixpkgs, which is why it needs
the overlay. `accelerator` is `cuda`, `rocm` or `cpu`, and `cuda` is the
default.

`accelerator` has to match your nixpkgs configuration. `cuda` needs
`nixpkgs.config.cudaSupport = true` and a configured `hardware.nvidia` stack.
`rocm` needs `nixpkgs.config.rocmSupport = true` and the ROCm and amdgpu stack.
A missing flag is refused with a message that says so.

Every option, with its type and default: [docs/OPTIONS.md](docs/OPTIONS.md).

## Use it without NixOS

Run the demo on a machine with an NVIDIA GPU:

```bash
nix run github:Daaboulex/unsloth-nix
```

It prints the version of each library and checks that PyTorch sees the GPU.
With `UNSLOTH_DEMO_TRAIN=1` set it also downloads a small model from Hugging
Face and attaches LoRA adapters to it.

Build one environment, or open a shell that has the CUDA environment and
Jupyter:

```bash
nix build github:Daaboulex/unsloth-nix#cuda
nix build github:Daaboulex/unsloth-nix#rocm
nix build github:Daaboulex/unsloth-nix#cpu
nix develop github:Daaboulex/unsloth-nix
```

## GPU builds need a binary cache

CUDA PyTorch is not on `cache.nixos.org`. Add the nixos-cuda cache once, so
you do not compile PyTorch from source:

```nix
nix.settings = {
  extra-substituters = [ "https://cache.nixos-cuda.org" ];
  extra-trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];
};
```

There is no cache to recommend for the ROCm environment. nixpkgs builds its
ROCm packages on Hydra, but a PyTorch with ROCm support may still compile on
your machine.

A one-off build that passes the cache on the command line is in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Known limits

- `x86_64-linux` only.
- Unsloth refuses to load without a GPU, so the CPU environment builds but
  cannot `import unsloth`.
- ROCm may fail to evaluate on a given nixpkgs pin. Unsloth's hard
  dependencies, `xformers` and `bitsandbytes`, are CUDA-centric, and ROCm
  support across the stack is still maturing in nixpkgs.
- Not everything comes from a cache. `unsloth`, `unsloth-zoo`, `accelerate` and
  the packages that depend on `accelerate` build from source.
- The demo checks for an NVIDIA GPU only and exits with an error without one.

## When something does not work

Run the demo. Where a library fails to import, it prints the import error in
place of that library's version.

## More

- [docs/DESIGN.md](docs/DESIGN.md): why it follows `main`, what differs from
  nixpkgs, every output of the flake
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md): what CI checks for each
  environment, and what it does not
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): the checks, building the GPU
  environments, how the pinned commits are updated
- [SECURITY.md](SECURITY.md): how to report a vulnerability

## License

This packaging flake is [MIT](./LICENSE). Upstream `unsloth` is Apache-2.0 and
`unsloth-zoo` is LGPL-3.0-or-later; their `meta.license` is preserved as
shipped by nixpkgs. Upstream's LICENSE file for `unsloth` states that the files
under `studio/` and `unsloth_cli/`, which are optional to install, are
AGPL-3.0.
