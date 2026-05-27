# Utility functions for Ambxst flake
{ nixpkgs }:

let
  linuxSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "i686-linux"
  ];
in {
  inherit linuxSystems;

  # Iterate over all supported Linux systems
  forAllSystems = f:
    builtins.foldl' (acc: system: acc // { ${system} = f system; }) {} linuxSystems;
}
