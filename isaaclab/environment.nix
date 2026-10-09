{
  lib,
  writeText,
  runCommand,
  pythonSet,
  selected,
  isaaclab-src,
  name,
  extraDependencies,
  pythonOverrides,
  constraintProjects,
}: let
  python = pythonSet.overrideScope (lib.composeManyExtensions pythonOverrides);
  dependencySpec =
    lib.zipAttrsWith (_: values: lib.unique (lib.concatLists values))
    [selected extraDependencies];
  constraintSpec = writeText "${name}-constraint-projects.json" (builtins.toJSON {
    projects =
      [
        {
          manifest = "${isaaclab-src}/pyproject.toml";
          extras = dependencySpec.isaaclab-dev;
        }
      ]
      ++ constraintProjects;
    dependencies = dependencySpec;
  });
  runtimeHook = builtins.path {
    path = ./runtime/sitecustomize.py;
    name = "isaaclab-sitecustomize.py";
  };
  checkRequirements = builtins.path {
    path = ./tests/check-dependencies.py;
    name = "isaaclab-check-dependencies.py";
  };
  environment = (python.mkVirtualEnv "${name}-environment" dependencySpec).overrideAttrs {
    postInstall = ''
      install -Dm644 ${runtimeHook} "$out/lib/python3.12/site-packages/sitecustomize.py"
    '';
  };
  check = runCommand "${name}-dependency-check" {} ''
    export PYTHONDONTWRITEBYTECODE=1
    ${environment}/bin/python ${checkRequirements} --installed ${constraintSpec} > "$out" 2>&1
  '';
in {
  inherit environment dependencySpec constraintSpec check;
  projectPython = python;
}
