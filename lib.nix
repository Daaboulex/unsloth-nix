# Shared environment builder — the single source for the three accelerator
# Python environments, imported by BOTH `perSystem` (checks/devShells/app) and
# the raw `flake.packages.<system>` surface in flake.nix, so the build targets
# and the eval-gates can never diverge.
#
# One overlay (git-main unsloth/zoo), three nixpkgs instances differing ONLY by
# the accelerator config flag:
#   cpu   — default config (torch/xformers/bitsandbytes are the cached
#           default-config builds from cache.nixos.org)
#   cuda  — config.cudaSupport = true  (unfree; not cached — build off-CI)
#   rocm  — config.rocmSupport = true  (not cached — build off-CI)
{
  nixpkgs,
  system,
  overlay,
}:
let
  mkPkgs =
    cfg:
    import nixpkgs {
      inherit system;
      overlays = [ overlay ];
      config = {
        allowUnfree = true;
      }
      // cfg;
    };

  # The fine-tuning stack. xformers + bitsandbytes are pulled in transitively by
  # `unsloth` regardless; they are listed here so the env exposes them directly
  # for `import xformers` / `python -m bitsandbytes` on the CUDA/CPU paths.
  pyStack = ps: [
    ps.unsloth
    ps.unsloth-zoo
    ps.torch
    ps.transformers
    ps.peft
    ps.trl
    ps.datasets
    ps.accelerate
    ps.triton
    ps.sentencepiece
    ps.protobuf
    ps.huggingface-hub
    ps.hf-transfer
    ps.ipython
  ];

  mkEnv = pkgs: pkgs.python3.withPackages pyStack;

  pkgsCpu = mkPkgs { };
  pkgsCuda = mkPkgs { cudaSupport = true; };
  pkgsRocm = mkPkgs { rocmSupport = true; };
in
{
  inherit pkgsCpu pkgsCuda pkgsRocm;

  cpuEnv = mkEnv pkgsCpu;
  cudaEnv = mkEnv pkgsCuda;
  rocmEnv = mkEnv pkgsRocm;
}
