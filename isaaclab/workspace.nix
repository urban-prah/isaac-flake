{
  lib,
  writers,
  coreutils,
  source,
}:
writers.writePython3Bin "isaaclab-workspace" {
  flakeIgnore = ["E501"];
  # This helper uses nixpkgs Python, independently of the simulator's SDK.
  makeWrapperArgs = [
    "--unset PYTHONPATH"
    "--unset LD_LIBRARY_PATH"
    "--unset LD_PRELOAD"
  ];
} (lib.replaceStrings
  ["@source@" "@cp@" "@chmod@"]
  ["${source}/isaaclab" "${coreutils}/bin/cp" "${coreutils}/bin/chmod"]
  (builtins.readFile ./runtime/workspace.py))
