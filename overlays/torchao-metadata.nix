{
  meta = {
    reason = "nixpkgs' torchao declares version 0.17.0 while the wheel it builds reports 0.17.0+git, so pythonMetadataCheckPhase fails the build and takes the whole unsloth env with it";
    added = "2026-07-30";
    upstream = "https://github.com/NixOS/nixpkgs/tree/master/pkgs/development/python-modules/torchao";
  };
  # A metadata mismatch is only observable by building the wheel, so this must
  # be probed by BUILDING the un-fixed package, never guessed from eval.
  dropWhenBuilds = pkgs: pkgs.python313Packages.torchao;
  overlay = _final: prev: {
    pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
      (_pyfinal: pyprev: {
        torchao = pyprev.torchao.overridePythonAttrs (_old: {
          dontCheckPythonMetadata = true;
        });
      })
    ];
  };
}
