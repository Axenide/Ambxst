{
  description = "Ambxst by Axenide";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixgl, quickshell, ... }: let
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
      # Import nixpkgs
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      lib = nixpkgs.lib;

      # Detect if running on NixOS
      isNixOS = pkgs ? config && pkgs.config ? nixosConfig;

      # NixGL
      nixGL = nixgl.packages.${system}.nixGLDefault;

      quickshellPkg = quickshell.packages.${system}.default;

      # Wrapper nixGL
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

      # Phosphor Icons
      ttf-phosphor-icons = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "ttf-phosphor-icons";
        version = "2.1.2";

        src = pkgs.fetchzip {
          url = "https://github.com/phosphor-icons/web/archive/refs/tags/v${version}.zip";
          sha256 = "sha256-96ivFjm0cBhqDKNB50klM7D3fevt8X9Zzm82KkJKMtU=";
          stripRoot = true;
        };

        dontBuild = true;

        installPhase = ''
          runHook preInstall

          install -Dm644 src/*/*.ttf -t $out/share/fonts/truetype
          install -Dm644 LICENSE -t $out/share/licenses/${pname}

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "A flexible icon family for interfaces, diagrams, presentations";
          homepage = "https://phosphoricons.com";
          license = licenses.mit;
          platforms = platforms.all;
        };
      };

      baseEnv = with pkgs; [
        (wrapWithNixGL quickshellPkg)

        (wrapWithNixGL gpu-screen-recorder)
        (wrapWithNixGL mpvpaper)

        brightnessctl
        ddcutil
        wl-clipboard
        cliphist
        sqlite
        hypridle
        fontconfig

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

        kdePackages.qtshadertools
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

        # Terminal
        kitty
        tmux

        # Fonts
        roboto
        barlow
        terminus_font
        terminus_font_ttf
        nerd-fonts.symbols-only
        noto-fonts
        noto-fonts-color-emoji
        ttf-phosphor-icons
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

        # Pass nixGL for non-NixOS
        ${lib.optionalString (!isNixOS) "export AMBXST_NIXGL=\"${nixGL}/bin/nixGL\""}

        export AMBXST_QS="${quickshellPkg}/bin/qs"

        # Delegate execution to CLI
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
