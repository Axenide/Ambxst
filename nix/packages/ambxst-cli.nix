{config, ...}: let
  inherit (config.flake) mkCli;
in {
  perSystem = { pkgs, self', ... }: {
    packages = {
      ambxst-cli = mkCli {
        inherit pkgs;
        shellPkg = self'.packages.ambxst;
      };

      default = self'.packages.ambxst-cli;
    };  
  };
}
