# Git-main override for unsloth + unsloth-zoo, applied via
# pythonPackagesExtensions so it composes with EVERY python3 the consuming
# nixpkgs builds — at any accelerator config (CPU / cudaSupport / rocmSupport).
#
# Only `src`, `version`, and the setuptools-scm pretend-version are replaced;
# nixpkgs' own `postPatch` (strips the AGPL-licensed CLI/Studio/MOE kernels,
# unpins setuptools, narrows the datasets guard), `pythonRelaxDeps`,
# `pythonRemoveDeps`, `dependencies`, `patches` (unsloth-zoo's
# dont-require-unsloth.patch) and `meta` are all INHERITED untouched. The whole
# robust dependency stack (torch/transformers/peft/trl/… ) stays exactly as
# nixpkgs ships it, substituted from cache.nixos.org — only the two pure-Python
# unsloth packages track git main.
#
# The pinned revs + hashes are the single source of truth in ./version.json,
# bumped daily by scripts/update.sh.
final: prev:
let
  v = builtins.fromJSON (builtins.readFile ./version.json);

  mkSrc =
    repo: spec:
    final.fetchFromGitHub {
      owner = "unslothai";
      inherit repo;
      inherit (spec) rev hash;
    };
in
{
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_pyfinal: pyprev: {
      unsloth-zoo = pyprev.unsloth-zoo.overridePythonAttrs (old: {
        inherit (v.unsloth-zoo) version;
        src = mkSrc "unsloth-zoo" v.unsloth-zoo;

        # A GitHub tarball carries no PKG-INFO and no .git, so setuptools-scm
        # cannot infer the version the PyPI sdist exposes — pin it explicitly.
        env = (old.env or { }) // {
          SETUPTOOLS_SCM_PRETEND_VERSION = v.unsloth-zoo.version;
        };

        # nixpkgs ships dont-require-unsloth.patch (a context patch that strips
        # the two "raise ImportError(... install Unsloth ...)" guards so zoo
        # builds/imports standalone despite the unsloth<->zoo circular dep). That
        # patch is cut against the PyPI sdist and does NOT apply to git main,
        # which moved both guards inside `if` blocks. Drop it and reproduce its
        # effect position/indent-agnostically — robust across upstream churn.
        patches = [ ];
        postPatch = (old.postPatch or "") + ''
          substituteInPlace unsloth_zoo/__init__.py \
            --replace-warn 'raise ImportError("Please install Unsloth via `pip install unsloth`!")' \
                           'pass  # nix: zoo builds standalone (unsloth<->zoo circular dep)'
        '';
      });

      unsloth = pyprev.unsloth.overridePythonAttrs (old: {
        inherit (v.unsloth) version;
        src = mkSrc "unsloth" v.unsloth;

        env = (old.env or { }) // {
          SETUPTOOLS_SCM_PRETEND_VERSION = v.unsloth.version;
        };

        # git main can pin unsloth-zoo to a newer release than nixpkgs ships;
        # relax so the git pair installs against each other. Extend (never
        # replace) nixpkgs' list. New upstream dep pins surface on the daily
        # bump's CPU build — add them here when they do (fail-loud by design).
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "unsloth-zoo" ];
      });
    })
  ];
}
