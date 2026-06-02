# NixOS module — installs the Unsloth fine-tuning environment system-wide.
#
# The env is built from the HOST's nixpkgs, so the consumer must apply this
# flake's overlay (nixpkgs.overlays = [ inputs.unsloth-nix.overlays.default ])
# and set the accelerator's config flag (config.cudaSupport / config.rocmSupport)
# on their own nixpkgs. The assertions below fail at eval time if the chosen
# accelerator does not match the host's nixpkgs config — so you never silently
# ship a CPU torch under a "cuda" label.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.unsloth;

  env = pkgs.python3.withPackages (ps: [
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
  ]);
in
{
  options.programs.unsloth = {
    enable = lib.mkEnableOption "the Unsloth (git-main) LLM fine-tuning environment";

    accelerator = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "cuda"
        "rocm"
      ];
      default = "cuda";
      description = ''
        Accelerator backend the installed environment targets. Must match the
        host nixpkgs config: `cuda` needs `nixpkgs.config.cudaSupport = true`
        plus a configured `hardware.nvidia` stack; `rocm` needs
        `nixpkgs.config.rocmSupport = true` plus the ROCm/amdgpu stack.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = env;
      defaultText = lib.literalexpression "the Unsloth python3 environment";
      description = "The Python environment package added to systemPackages.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.accelerator != "cuda" || (pkgs.config.cudaSupport or false);
        message = ''
          programs.unsloth.accelerator = "cuda" requires nixpkgs.config.cudaSupport = true
          and a configured hardware.nvidia stack on the host.
        '';
      }
      {
        assertion = cfg.accelerator != "rocm" || (pkgs.config.rocmSupport or false);
        message = ''
          programs.unsloth.accelerator = "rocm" requires nixpkgs.config.rocmSupport = true
          and a configured ROCm/amdgpu stack on the host.
        '';
      }
    ];

    environment.systemPackages = [ cfg.package ];
  };
}
