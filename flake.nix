{
  description = "Isaac Nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks.url = "github:cachix/git-hooks.nix";
    isaaclab-src = {
      url = "github:isaac-sim/IsaacLab/v3.0.0-EA";
      flake = false;
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    git-hooks,
    isaaclab-src,
    pyproject-nix,
    uv2nix,
    pyproject-build-systems,
  }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems (
        system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
      );

    packages = forAllSystems (pkgs:
      import ./default.nix {
        inherit pkgs isaaclab-src pyproject-nix uv2nix pyproject-build-systems;
      });
  in {
    inherit packages;
    lib.mkIsaacLab = {system ? "x86_64-linux", ...} @ arguments:
      self.packages.${system}.isaaclab.override (builtins.removeAttrs arguments ["system"]);
    apps = forAllSystems (pkgs:
      pkgs.lib.mapAttrs (_: package: {
        type = "app";
        program = pkgs.lib.getExe package;
      })
      self.packages.${pkgs.stdenv.hostPlatform.system});
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with self.packages.${pkgs.stdenv.hostPlatform.system}; [
          isaacsim
          isaaclab
          isaacsim-mcp
          isaacsim-webrtc-streaming-client
        ];
        shellHook = ''
          export ISAAC_SIM_DIR="${self.packages.${pkgs.stdenv.hostPlatform.system}.isaacsim}/isaacsim"
          export ISAAC_LAB_DIR="$(${pkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.isaaclab.sourceWorkspace})"
          ${self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit-check.shellHook}
        '';
      };
    });

    formatter = forAllSystems (
      pkgs: let
        inherit (self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit-check) config;
        inherit (config) package configFile;
      in
        pkgs.writeShellScriptBin "pre-commit-run" "${pkgs.lib.getExe package} run --all-files --config ${configFile}"
    );

    checks = forAllSystems (pkgs: let
      mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.isaacsim-mcp;
    in {
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) isaaclab;
      isaaclab-dependencies = self.packages.${pkgs.stdenv.hostPlatform.system}.isaaclab.tests.dependencies;
      isaaclab-consumer-extras =
        pkgs.runCommand "isaaclab-consumer-extras-check" {
          nativeBuildInputs = [pkgs.python3];
        } ''
          python ${./isaaclab/tests/consumer-extras.py} \
            ${self.packages.${pkgs.stdenv.hostPlatform.system}.isaaclab.environment}/bin/python \
            ${./isaaclab/tests/check-dependencies.py} > "$out"
        '';
      isaaclab-workspace =
        pkgs.runCommand "isaaclab-workspace-check" {
          nativeBuildInputs = [pkgs.python3];
        } ''
          python ${./isaaclab/tests/workspace.py} \
            ${self.packages.${pkgs.stdenv.hostPlatform.system}.isaaclab} ${isaaclab-src} > "$out"
        '';
      isaacsim-mcp = mcp;
      isaacsim-mcp-smoke =
        pkgs.runCommand "isaacsim-mcp-smoke" {
          nativeBuildInputs = [mcp.pythonEnv];
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        } ''
          python ${./isaacsim/mcp/smoke.py} ${pkgs.lib.getExe mcp} > "$out"
        '';
      pre-commit-check = git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
        src = ./.;
        package = pkgs.prek;
        hooks = {
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
        };
      };
    });
  };
}
