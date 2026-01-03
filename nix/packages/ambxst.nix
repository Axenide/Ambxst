{ config, inputs, ... }: let
  inherit (config.flake.lib) mkAmbxst;
in {
  perSystem = { pkgs, self', ... }: {
    packages.ambxst = mkAmbxst { inherit pkgs; src = inputs.ambxst; };
    packages.default = self'.packages.ambxst;
  };
}
