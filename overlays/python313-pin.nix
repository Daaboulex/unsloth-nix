# Every env eval died with "torchao-0.17.0 not supported for interpreter
# python3.14" the moment nixpkgs made python 3.14 the default python3:
# unsloth-zoo hard-depends on torchao, which nixpkgs disables on 3.14.
{
  meta = {
    reason = "torchao (unsloth-zoo dep) is disabled on python 3.14, nixpkgs' default python3; pin the env interpreter to python 3.13";
    added = "2026-07-13";
    upstream = "https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/python-modules/torchao/default.nix";
  };
  # Healed when torchao evaluates on the DEFAULT interpreter again.
  dropWhen = pkgs: (builtins.tryEval pkgs.python3Packages.torchao.drvPath).success;
  overlay = final: _prev: { unslothPython = final.python313; };
}
