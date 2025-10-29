{
  description = "Ambxst by Axenide";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixgl }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    # Ejecutable de nixGL
    nixGL = nixgl.packages.${system}.nixGLDefault;

    # Función para envolver binarios con nixGL
    wrapWithNixGL = pkg: pkgs.symlinkJoin {
      name = "${pkg.pname or pkg.name}-nixGL";
      paths = [ pkg ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in $out/bin/*; do
          if [ -x "$bin" ]; then
            mv "$bin" "$bin.orig"
            makeWrapper ${nixGL}/bin/nixGL "$bin" --add-flags "$bin.orig"
          fi
        done
      '';
    };

  in {
    packages.${system}.default = pkgs.buildEnv {
      name = "ambxst";
      paths = with pkgs; [
        (wrapWithNixGL quickshell)
        (wrapWithNixGL gpu-screen-recorder)
        (wrapWithNixGL mpvpaper)

        wl-clipboard
        cliphist
        nixGL

        # OpenGL / Wayland stack
        mesa
        libglvnd
        egl-wayland
        wayland

        # Qt6 deps comunes
        qt6.qtbase
        qt6.qtsvg
        qt6.qttools
        qt6.qtwayland
        qt6.qtdeclarative
        qt6.qtimageformats
        qt6.qtwebengine

        # Iconos y temas
        kdePackages.breeze-icons
        hicolor-icon-theme

        # Extras
        fuzzel
        wtype
        imagemagick
        matugen
        ffmpeg
      ];
    };
  };
}
