{
  description = "Unsloth (git main) packaged for NixOS — CPU/CUDA/ROCm LoRA fine-tuning envs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:Daaboulex/nix-packaging-standard?ref=v2.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  # Note: the GPU caches needed to substitute CUDA/ROCm torch are configured by
  # the user (see README "Building the GPU envs"), NOT via a flake `nixConfig`
  # block — the latter emits an "ignoring untrusted flake configuration" warning
  # on every command and is ignored by the byte-locked CI anyway.
  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      let
        systems = [ "x86_64-linux" ];

        # The three accelerator envs for a given system, from the single shared
        # builder — used by both perSystem (below) and flake.packages (bottom).
        envsFor =
          system:
          import ./lib.nix {
            inherit (inputs) nixpkgs;
            inherit system;
            overlay = self.overlays.default;
          };
      in
      {
        inherit systems;

        imports = [ inputs.std.flakeModules.base ];

        # System-independent flake outputs.
        flake.overlays.default = import ./overlay.nix;
        flake.nixosModules.default = import ./module.nix;

        # Raw per-system package surface. base.nix auto-aliases ONLY
        # `perSystem.packages` (config.packages) into BUILT `package-*` checks,
        # so exposing cuda/rocm/default here keeps them as real `nix build .#x`
        # targets WITHOUT making CI try to realize their uncached GPU closures.
        flake.packages = builtins.listToAttrs (
          map (system: {
            name = system;
            value =
              let
                e = envsFor system;
              in
              {
                cuda = e.cudaEnv;
                rocm = e.rocmEnv;
                default = e.cudaEnv; # primary: GPU fine-tuning
              };
          }) systems
        );

        perSystem =
          {
            system,
            config,
            lib,
            ...
          }:
          let
            e = envsFor system;

            # Eval-gate: force the FULL derivation graph of an env to EVALUATE
            # (catching version/dep/accelerator breakage) WITHOUT realizing it.
            # `builtins.seq env.drvPath` forces the whole withPackages closure's
            # drvPaths transitively; `env` is NOT a build input, so CI never
            # builds the uncached CUDA/ROCm torch. Modeled on
            # std.lib.nixosModuleCheck. (Negative-engineering: this fails loudly
            # if the overlay or a dep stops evaluating under the accel config —
            # verified by temporarily breaking the overlay hash.)
            evalGate =
              name: env:
              e.pkgsCpu.runCommand "unsloth-${name}-eval" {
                ok = builtins.seq env.drvPath "evaluated";
              } ''printf '%s\n' "$ok" > "$out"'';

            # The demo runs through the CUDA env's own interpreter.
            demoApp = e.pkgsCuda.writeShellApplication {
              name = "unsloth-demo";
              runtimeInputs = [ e.cudaEnv ];
              text = ''exec python ${./apps/demo.py} "$@"'';
            };
          in
          {
            # ONLY the CPU env is a built check: its deps are the cached
            # default-config builds, so CI realizes just the tiny pure-Python
            # git-overridden unsloth + unsloth-zoo on top.
            packages.cpu = e.cpuEnv;

            checks = {
              # Real (cheap) build: the interpreter imports the CPU-importable
              # stack. unsloth / unsloth-zoo are deliberately NOT imported here:
              # both raise at import time without a GPU (upstream "Unsloth
              # currently only supports GPUs!" — nixpkgs sets
              # dontUsePythonImportsCheck for the same reason). Building the env
              # already validates that they BUILD; importing them needs a GPU
              # runner, which CI is not. The CUDA/ROCm demo app exercises that.
              smoke-cpu = e.pkgsCpu.runCommand "unsloth-smoke-cpu" { } ''
                ${e.cpuEnv}/bin/python - <<'PY'
                import torch, transformers, datasets, accelerate, peft, trl
                print("torch", torch.__version__, "transformers", transformers.__version__)
                PY
                touch "$out"
              '';

              # Eval-only gates for the uncached GPU envs.
              cuda-eval = evalGate "cuda" e.cudaEnv;
              rocm-eval = evalGate "rocm" e.rocmEnv;

              # Module instantiation gate (cpu accelerator => no GPU host config).
              module-eval-nixos = inputs.std.lib.nixosModuleCheck {
                inherit (inputs) nixpkgs;
                inherit system;
                overlays = [ self.overlays.default ];
                module = ./module.nix;
                config = {
                  nixpkgs.config.allowUnfree = true;
                  programs.unsloth = {
                    enable = true;
                    accelerator = "cpu";
                  };
                };
              };
            };

            # Dev shells layer the env onto the standard's lint/format shell
            # (config.pre-commit.devShell) — never drop it. `default` overrides
            # the standard's lint-only shell (mkForce) but keeps its hooks + nil.
            devShells = {
              default = lib.mkForce (
                e.pkgsCuda.mkShell {
                  inputsFrom = [ config.pre-commit.devShell ];
                  packages = [
                    e.cudaEnv
                    e.pkgsCuda.python3Packages.jupyter
                    e.pkgsCuda.nil
                  ];
                }
              );
              cpu = e.pkgsCpu.mkShell {
                inputsFrom = [ config.pre-commit.devShell ];
                packages = [ e.cpuEnv ];
              };
              rocm = e.pkgsRocm.mkShell {
                inputsFrom = [ config.pre-commit.devShell ];
                packages = [ e.rocmEnv ];
              };
            };

            apps.default = {
              type = "app";
              program = "${demoApp}/bin/unsloth-demo";
              meta.description = "Assert CUDA and print the Unsloth fine-tuning stack versions";
            };
          };
      }
    );
}
