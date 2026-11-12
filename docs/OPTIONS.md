# Options

Every option the modules of this flake declare. This file is generated from the module sources: change a description there, then run `nix run .#std-write-option-reference`.

## NixOS module

Declared in [module.nix](../module.nix).

### `programs.unsloth.enable`

Whether to enable the Unsloth (git-main) LLM fine-tuning environment.

Type: `boolean`. Default: `false`.

### `programs.unsloth.package`

The Python environment package added to systemPackages.

Type: `package`. Default: `the Unsloth python environment`.

### `programs.unsloth.accelerator`

Accelerator backend the installed environment targets. Must match the
host nixpkgs config: `cuda` needs `nixpkgs.config.cudaSupport = true`
plus a configured `hardware.nvidia` stack; `rocm` needs
`nixpkgs.config.rocmSupport = true` plus the ROCm/amdgpu stack.

Type: `one of "cpu", "cuda", "rocm"`. Default: `"cuda"`.
