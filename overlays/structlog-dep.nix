{
  meta = {
    reason = "unsloth git-main added a structlog runtime dependency that nixpkgs' unsloth release predates, so pythonRuntimeDepsCheck fails every daily bump";
    added = "2026-07-30";
    upstream = "https://github.com/unslothai/unsloth";
  };
  # Healed when nixpkgs' own unsloth propagates structlog. tryEval so a
  # separately-broken interpreter cannot error the probe into a false heal.
  dropWhen =
    pkgs:
    let
      probe = builtins.tryEval (
        builtins.any (d: (d.pname or "") == "structlog") (
          pkgs.python3Packages.unsloth.propagatedBuildInputs or [ ]
        )
      );
    in
    probe.success && probe.value;
  overlay = _final: prev: {
    pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
      (_pyfinal: pyprev: {
        unsloth = pyprev.unsloth.overridePythonAttrs (old: {
          dependencies = (old.dependencies or [ ]) ++ [ pyprev.structlog ];
        });
      })
    ];
  };
}
