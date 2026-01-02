# Though i didn't copy the code directly the code's structure and var namees are heavily inspired from rexi's kurukuru bar https://github.com/Rexcrazy804/Zaphkiel/blob/master/pkgs/kurukurubar.nix

{ inputs, ... }: {
  perSystem = { pkgs, lib, self', inputs', ... }: 
    let
      quickshellPkg = inputs'.quickshell.packages.default;

      fontconfig = pkgs.makeFontsConf {
        fontDirectories = [
          self'.packages.phosphor-icons
        ];
      };

      qsConfig = pkgs.stdenvNoCC.mkDerivation {
        name = "ambxst-config";
        src = inputs.ambxst;
        installPhase = ''
          mkdir -p $out
          cp -r ./. $out
        '';
      };

      qmlPath = lib.makeSearchPath "lib/qt-6/qml" [
        pkgs.kdePackages.qtbase
        pkgs.kdePackages.qtdeclarative
        pkgs.kdePackages.qtmultimedia
        pkgs.kdePackages.syntax-highlighting
      ];

    in {
      packages.ambxst = pkgs.symlinkJoin {
        pname = "ambxst-shell";
        version = "0.1.0"; 
        paths = [
          quickshellPkg
          pkgs.tesseract
          pkgs.power-profiles-daemon
          pkgs.brightnessctl
          pkgs.matugen
          pkgs.pipewire
          pkgs.upower
          pkgs.jq                            
          pkgs.procps                        
          pkgs.libnotify                     
          pkgs.gpu-screen-recorder
          pkgs.grim
          pkgs.easyeffects
          pkgs.blueman
          pkgs.mpvpaper
          pkgs.pwvucontrol
          pkgs.wireplumber
          pkgs.wl-clip-persist
          pkgs.wl-clipboard
          pkgs.wlsunset
          pkgs.wtype
          pkgs.tmux
          pkgs.imagemagick
          pkgs.slurp
          pkgs.zbar
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

      packages.default = self'.packages.ambxst;
    };
}
