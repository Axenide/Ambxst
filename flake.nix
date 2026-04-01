{
  description = "Ambxst - An Axtremely customizable shell by Axenide";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    axctl = {
      url = "github:Axenide/axctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, axctl, ... }:
    let
      ambxstLib = import ./nix/lib.nix { inherit nixpkgs; };
    in {
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nix/modules ];
        programs.ambxst.enable = lib.mkDefault true;
        programs.ambxst.package = lib.mkDefault self.packages.${pkgs.system}.default;
      };

      packages = ambxstLib.forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          lib = nixpkgs.lib;

          Ambxst = import ./nix/packages {
            inherit pkgs lib self system axctl;
          };
        in {
          default = Ambxst;
          Ambxst = Ambxst;
        }
      );

      devShells = ambxstLib.forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          Ambxst = self.packages.${system}.default;
        in {
          default = pkgs.mkShell {
            packages = [ Ambxst ];
            shellHook = ''
              export QML2_IMPORT_PATH="${Ambxst}/lib/qt-6/qml:$QML2_IMPORT_PATH"
              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              echo "Ambxst dev environment loaded."
            '';
          };
        }
      );

      apps = ambxstLib.forAllSystems (system:
        let
          Ambxst = self.packages.${system}.default;
        in {
          default = {
            type = "app";
            program = "${Ambxst}/bin/ambxst";
          };
        }
      );
    };
}
