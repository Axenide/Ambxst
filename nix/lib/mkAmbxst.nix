# Though i didn't copy the code directly the code's structure and var namees are heavily inspired from rexi's kurukuru bar https://github.com/Rexcrazy804/Zaphkiel/blob/master/pkgs/kurukurubar.nix

{ inputs, self, lib, ... }: {
  flake.mkAmbxst = {pkgs, src}:  
    let
      system = pkgs.stdenv.hostPlatform.system;
      quickshellPkg = inputs.quickshell.packages.${system}.default;
      qt6 = pkgs.kdePackages;

      fontconfig = pkgs.makeFontsConf {
        fontDirectories = [
          self.packages.${system}.phosphor-icons
          pkgs.roboto
          pkgs.roboto-mono
          pkgs.league-gothic
          pkgs.terminus_font
          pkgs.terminus_font_ttf
          pkgs.dejavu_fonts
          pkgs.liberation_ttf

          pkgs.# Nerd Fonts
          pkgs.nerd-fonts.symbols-only

          pkgs.# Noto family
          pkgs.noto-fonts
          pkgs.noto-fonts-color-emoji
          pkgs.noto-fonts-cjk-sans
          pkgs.noto-fonts-cjk-serif
        ];
      };

      qsConfig = pkgs.stdenvNoCC.mkDerivation {
        inherit src;
        name = "ambxst-config";
        installPhase = ''
          mkdir -p $out
          cp -r ./. $out
        '';
      };

      qmlPath = lib.makeSearchPath "lib/qt-6/qml" [
        qt6.qtbase
        qt6.qtdeclarative
        qt6.syntax-highlighting
        qt6.qtmultimedia 
      ];
    in 
      pkgs.symlinkJoin {
        pname = "ambxst-shell";
        version = "0.1.0"; 
        paths = [
          quickshellPkg
          pkgs.tesseract
          pkgs.power-profiles-daemon
          pkgs.brightnessctl
          pkgs.matugen
          pkgs.upower
          pkgs.jq                            
          pkgs.procps                        
          pkgs.kitty
          pkgs.libnotify                     
          pkgs.gpu-screen-recorder
          pkgs.grim
          pkgs.easyeffects
          pkgs.blueman
          pkgs.mpvpaper
          pkgs.pwvucontrol
          pkgs.wl-clip-persist
          pkgs.wl-clipboard
          pkgs.wlsunset
          pkgs.wtype
          pkgs.tmux
          pkgs.imagemagick
          pkgs.slurp
          pkgs.zbar
          pkgs.sqlite
          pkgs.x264
          pkgs.ffmpeg
          pkgs.playerctl
          pkgs.pipewire
          pkgs.wireplumber
          pkgs.ddcutil
          qt6.qtmultimedia
        ]; 

        nativeBuildInputs = [ pkgs.makeWrapper ];

        postBuild = ''
          makeWrapper ${lib.getExe quickshellPkg} $out/bin/ambxst-shell \
            --set FONTCONFIG_FILE "${fontconfig}" \
            --set QML2_IMPORT_PATH "${qmlPath}" \
            --add-flags "-p ${qsConfig}" \
            --prefix PATH : "$out/bin"
          rm $out/bin/quickshell
        '';

        meta.mainProgram = "ambxst-shell";
    };
}
