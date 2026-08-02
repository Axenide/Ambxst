# Main Ambxst[+] package
{ pkgs, lib, self, system, axctl, version }:

let
  quickshellPkg = pkgs.quickshell;
  axctlPkg = axctl.packages.${system}.default;

  # Import sub-packages
  ttf-phosphor-icons = import ./phosphor-icons.nix { inherit pkgs; };

  # Import modular package lists
  corePkgs = import ./core.nix { inherit pkgs quickshellPkg; };
  toolsPkgs = import ./tools.nix { inherit pkgs; };
  mediaPkgs = import ./media.nix { inherit pkgs; };
  appsPkgs = import ./apps.nix { inherit pkgs; };
  fontsPkgs = import ./fonts.nix { inherit pkgs ttf-phosphor-icons; };
  tesseractPkgs = import ./tesseract.nix { inherit pkgs; };

  # Combine all packages (NixOS-specific deps handled by the module)
  baseEnv = corePkgs
    ++ [ axctlPkg ]
    ++ toolsPkgs
    ++ mediaPkgs
    ++ appsPkgs
    ++ fontsPkgs
    ++ tesseractPkgs;

  envAmbxstPlus = pkgs.buildEnv {
    name = "ambxst+-env";
    paths = baseEnv;
  };

  # Create fontconfig configuration to find bundled fonts. FONTCONFIG_FILE
  # replaces the whole config, so this must include the system config
  # (otherwise the user's fontconfig settings would be silently shadowed).
  fontconfigConf = pkgs.writeTextDir "etc/fonts/fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>${envAmbxstPlus}/share/fonts</dir>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <include ignore_missing="yes">${pkgs.fontconfig.out}/etc/fonts/fonts.conf</include>
    </fontconfig>
  '';

  # Copy shell sources to the Nix store (excluding CI/docs cruft)
  shellSrc = pkgs.stdenv.mkDerivation {
    pname = "ambxst+-shell";
    inherit version;
    src = lib.cleanSourceWith {
      src = self;
      filter = path: type:
        (lib.cleanSourceFilter path type)
        && !(builtins.elem (baseNameOf path) [ "screenshots" ".github" "tests" ]);
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };

  launcher = pkgs.writeShellScriptBin "ambxst+" ''
    export AMBXST_QS="${quickshellPkg}/bin/qs"
    export PATH="${envAmbxstPlus}/bin:$PATH"

    # Set QML2_IMPORT_PATH to include modules from envAmbxstPlus (like syntax-highlighting)
    export QML2_IMPORT_PATH="${envAmbxstPlus}/lib/qt-6/qml:$QML2_IMPORT_PATH"
    export QML_IMPORT_PATH="$QML2_IMPORT_PATH"

    # Make bundled fonts available to fontconfig (without shadowing user config)
    export FONTCONFIG_FILE="${fontconfigConf}/etc/fonts/fonts.conf"

    # Delegate execution to CLI (now in the Nix store)
    exec ${shellSrc}/cli.sh "$@"
  '';

in pkgs.buildEnv {
   name = "ambxst+-${version}";
   paths = [ envAmbxstPlus launcher ];
   meta = with pkgs.lib; {
     description = "Ambxst[+] - A Quickshell desktop shell";
     homepage = "https://github.com/git-napkin/ambxst+-plus";
     license = licenses.gpl3;
     platforms = platforms.linux;
     mainProgram = "ambxst+";
   };
}
