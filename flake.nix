{
  description = "Universal Quickshell environment (any GPU)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixgl, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            quickshell
            mesa
            libglvnd
            egl-wayland
            wayland
            xorg.libX11
            xorg.libXext
            xorg.libXrandr
            qt6.qtwayland
            qt6.qtbase
            qt6.qtsvg
            qt6.qttools
            kdePackages.breeze-icons
            hicolor-icon-theme
            dbus
            nixgl.packages.${system}.nixGLDefault
          ];

          shellHook = ''
            export QT_QPA_PLATFORM=wayland
            export QT_PLUGIN_PATH=${pkgs.qt6.qtbase}/lib/qt6/plugins
            export QT_DEBUG_PLUGINS=0
            export LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:${pkgs.mesa}/lib:${pkgs.qt6.qtbase}/lib:$LD_LIBRARY_PATH
            export XDG_CURRENT_DESKTOP=KDE
            export XDG_ICON_THEME=Breeze

            alias qs="nixGL ${pkgs.quickshell}/bin/quickshell"

            echo "✨ Quickshell environment ready!"
            echo "Use: qs -p shell.qml"
          '';
        };
      });
}
