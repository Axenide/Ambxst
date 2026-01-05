{ config, inputs, ... }: let
  inherit (config.flake) mkAmbxst;
in {
  perSystem = { pkgs, ... }: {
    packages.ambxst = mkAmbxst { inherit pkgs; src = inputs.ambxst; };
  };
}
