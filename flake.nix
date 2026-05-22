{
  description = "NothingLess - An Axtremely customizable shell by Leriart";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    axctl = {
      url = "github:Leriart/axctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, axctl, ... }:
    let
      nothinglessLib = import ./nix/lib.nix { inherit nixpkgs; };
      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
    in {
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nix/modules ];
        programs.nothingless.enable = lib.mkDefault true;
        programs.nothingless.package = lib.mkDefault self.packages.${pkgs.system}.default;
      };

      packages = nothinglessLib.forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          lib = nixpkgs.lib;

          NothingLess = import ./nix/packages {
            inherit pkgs lib self system axctl version;
          };
        in {
          default = NothingLess;
          NothingLess = NothingLess;
        }
      );

      devShells = nothinglessLib.forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          NothingLess = self.packages.${system}.default;
        in {
          default = pkgs.mkShell {
            packages = [ NothingLess ];
            shellHook = ''
              export QML2_IMPORT_PATH="${NothingLess}/lib/qt-6/qml:$QML2_IMPORT_PATH"
              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              echo "NothingLess dev environment loaded."
            '';
          };
        }
      );

      apps = nothinglessLib.forAllSystems (system:
        let
          NothingLess = self.packages.${system}.default;
        in {
          default = {
            type = "app";
            program = "${NothingLess}/bin/nothingless";
          };
        }
      );
    };
}
