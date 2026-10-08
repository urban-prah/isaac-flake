{
  lib,
  pkgs,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}: let
  version = "2.2.2";
  rev = "8df4ed105e4202dfb6dff836bd1871bf5eccd308";
  upstream = pkgs.fetchurl {
    name = "kit-usd-agents-${rev}.tar.gz";
    url = "https://codeload.github.com/NVIDIA-Omniverse/kit-usd-agents/tar.gz/${rev}";
    hash = "sha256-KvxPVx9s2bBPmGez6zLGRtD80mb7RH/OLIR4bemBKwM=";
  };
  lfsFiles = builtins.fromJSON (builtins.readFile ./mcp/lfs-files.json);
  data = pkgs.runCommand "isaacsim-mcp-data-${version}" {} ''
    tar -xzf ${upstream}
    cp -r kit-usd-agents-${rev}/source/aiq/isaacsim_fns/src/isaacsim_fns/data "$out"
    chmod -R u+w "$out"
    ${lib.concatMapStringsSep "\n" (entry: let
      file = pkgs.fetchurl {
        url = "https://media.githubusercontent.com/media/NVIDIA-Omniverse/kit-usd-agents/${rev}/source/aiq/isaacsim_fns/src/isaacsim_fns/data/${entry.path}";
        inherit (entry) hash;
      };
    in ''cp ${file} "$out/${entry.path}"'')
    lfsFiles}
  '';
  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./mcp;};
  python = pkgs.python313;
  pythonSet = (pkgs.callPackage pyproject-nix.build.packages {inherit python;}).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
      (final: prev: let
        sourcePackage = name: subdirectory: buildSystem:
          prev.${name}.overrideAttrs (old: {
            src = upstream;
            sourceRoot = "kit-usd-agents-${rev}/${subdirectory}";
            postUnpack = "";
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ final.resolveBuildSystem buildSystem;
          });
      in {
        # This legacy sdist predates pyproject.toml and does not declare its backend.
        wikipedia = prev.wikipedia.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ final.resolveBuildSystem {setuptools = [];};
        });
        isaacsim-mcp = sourcePackage "isaacsim-mcp" "source/mcp/isaacsim_mcp" {poetry-core = [];};
        isaacsim-fns = (sourcePackage "isaacsim-fns" "source/aiq/isaacsim_fns" {poetry-core = [];}).overrideAttrs (old: {
          postPatch =
            (old.postPatch or "")
            + ''
              rm -r src/isaacsim_fns/data
              cp -r ${data} src/isaacsim_fns/data
            '';
        });
        ovgenai-retrieval = sourcePackage "ovgenai-retrieval" "source/aiq/ovgenai_retrieval" {setuptools = [];};
      })
    ]
  );
  pythonEnv = (pythonSet.mkVirtualEnv "isaacsim-mcp-env-${version}" workspace.deps.default).overrideAttrs (_: {
    # NAT namespace packages ship different PyPI READMEs at the same path.
    venvIgnoreCollisions = ["lib/python${python.pythonVersion}/site-packages/nat/meta/pypi.md"];
  });
  configuration = pkgs.runCommand "isaacsim-mcp-config.yaml" {} ''
    tar -xOf ${upstream} kit-usd-agents-${rev}/source/mcp/isaacsim_mcp/workflows/config.yaml > "$out"
  '';
in
  pkgs.runCommand "isaacsim-mcp-${version}" {
    nativeBuildInputs = [pkgs.makeWrapper];
    passthru = {inherit pythonEnv data rev;};
    meta = {
      description = "NVIDIA Isaac Sim documentation MCP server";
      homepage = "https://github.com/NVIDIA-Omniverse/kit-usd-agents/tree/${rev}/source/mcp/isaacsim_mcp";
      license = lib.licenses.asl20;
      platforms = ["x86_64-linux"];
      mainProgram = "isaacsim-mcp";
    };
  } ''
    mkdir -p "$out/bin" "$out/share/isaacsim-mcp"
    cp ${./mcp/launch.py} "$out/share/isaacsim-mcp/launch.py"
    cp ${configuration} "$out/share/isaacsim-mcp/config.yaml"
    makeWrapper ${pythonEnv}/bin/python "$out/bin/isaacsim-mcp" \
      --add-flags "$out/share/isaacsim-mcp/launch.py" \
      --prefix PATH : ${pythonEnv}/bin
  ''
