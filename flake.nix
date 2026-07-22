{
  description = "Ambxst[+] - A Quickshell desktop shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    axctl = {
      url = "github:git-napkin/axctl-plus/dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, axctl, ... }:
    let
      ambxstPlusLib = import ./nix/lib.nix { inherit nixpkgs; };
      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
    in {
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nix/modules ];
        programs.ambxst-plus.enable = lib.mkDefault true;
        programs.ambxst-plus.package = lib.mkDefault self.packages.${pkgs.system}.default;
      };

      packages = ambxstPlusLib.forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          lib = nixpkgs.lib;

          ambxstPlus = import ./nix/packages {
            inherit pkgs lib self system axctl version;
          };
        in {
          default = ambxstPlus;
          ambxstPlus = ambxstPlus;
        }
      );

      devShells = ambxstPlusLib.forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          ambxstPlus = self.packages.${system}.default;
        in {
          default = pkgs.mkShell {
            packages = [ ambxstPlus ];
            shellHook = ''
              export QML2_IMPORT_PATH="${ambxstPlus}/lib/qt-6/qml:$QML2_IMPORT_PATH"
              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              echo "Ambxst[+] dev environment loaded."
            '';
          };
        }
      );

      apps = ambxstPlusLib.forAllSystems (system:
        let
          ambxstPlus = self.packages.${system}.default;
        in {
          default = {
            type = "app";
            program = "${ambxstPlus}/bin/ambxst+";
          };
        }
      );
    };
}
