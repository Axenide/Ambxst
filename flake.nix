{
  description = "Ambxst by Axenide";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixgl, ... }: let
    linuxSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "i686-linux"
    ];

    forAllSystems = f:
      builtins.foldl' (acc: system: acc // { ${system} = f system; }) {} linuxSystems;
  in {
    nixosModules.default = { config, lib, ... }: {
      config = lib.mkIf (!config.networking.networkmanager.enable) {
        networking.networkmanager.enable = lib.mkDefault true;
      };
    };

    packages = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      lib = nixpkgs.lib;
      isNixOS = pkgs ? config && pkgs.config ? nixosConfig;
      nixGL = nixgl.packages.${system}.nixGLDefault;

      wrapWithNixGL = pkg:
        if isNixOS then pkg else pkgs.symlinkJoin {
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

      # Build the ambxst-auth binary for lockscreen
      ambxst-auth = pkgs.stdenv.mkDerivation {
        pname = "ambxst-auth";
        version = "1.0.0";
        src = ./modules/lockscreen;
        
        nativeBuildInputs = [ pkgs.gcc ];
        buildInputs = [ pkgs.pam ];
        
        buildPhase = ''
          gcc -o ambxst-auth auth.c -lpam -Wall -Wextra -O2
        '';
        
        installPhase = ''
          mkdir -p $out/bin
          cp ambxst-auth $out/bin/
          chmod 755 $out/bin/ambxst-auth
        '';
      };

      baseEnv = with pkgs; [
        (wrapWithNixGL quickshell)
        (wrapWithNixGL gpu-screen-recorder)
        (wrapWithNixGL mpvpaper)

        brightnessctl
        ddcutil
        wl-clipboard
        cliphist
      ] ++ (if isNixOS then [ 
        ambxst-auth
        power-profiles-daemon 
        networkmanager 
      ] else [ 
        nixGL 
      ]) ++ (with pkgs; [
        mesa
        libglvnd
        egl-wayland
        wayland

        qt6.qtbase
        qt6.qtsvg
        qt6.qttools
        qt6.qtwayland
        qt6.qtdeclarative
        qt6.qtimageformats

        kdePackages.breeze-icons
        hicolor-icon-theme
        fuzzel
        wtype
        imagemagick
        matugen
        ffmpeg
        playerctl

        pipewire
        wireplumber
      ]);

      envAmbxst = pkgs.buildEnv {
        name = "Ambxst-env";
        paths = baseEnv;
      };

      launcher = pkgs.writeShellScriptBin "ambxst" ''
        # Ensure ambxst-auth is in PATH for lockscreen
        ${lib.optionalString isNixOS ''
          export PATH="${ambxst-auth}/bin:$PATH"
        ''}
        ${lib.optionalString (!isNixOS) ''
          # On non-NixOS, use local build from ~/.local/bin
          export PATH="$HOME/.local/bin:$PATH"
        ''}
        # Wrap QuickShell with nixGL if needed, then delegate to CLI script
        ${lib.optionalString (!isNixOS) "export AMBXST_NIXGL=\"${nixGL}/bin/nixGL\""}
        export AMBXST_QS="${pkgs.quickshell}/bin/qs"
        exec ${self}/cli.sh "$@"
      '';

      Ambxst = pkgs.buildEnv {
        name = "Ambxst";
        paths = [ envAmbxst launcher ];
      };
    in {
      default = Ambxst;
      Ambxst = Ambxst;
    });
  };
}
