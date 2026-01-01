# Main Ambxst package
{ pkgs, lib, self, system, quickshell, ambxstLib }:

let
  isNixOS = ambxstLib.detectNixOS pkgs;
  quickshellPkg = quickshell.packages.${system}.default;

  # Import sub-packages
  ttf-phosphor-icons = import ./phosphor-icons.nix { inherit pkgs; };

  # Import modular package lists
  corePkgs = import ./core.nix { inherit pkgs quickshellPkg; };
  toolsPkgs = import ./tools.nix { inherit pkgs; };
  mediaPkgs = import ./media.nix { inherit pkgs; };
  appsPkgs = import ./apps.nix { inherit pkgs; };
  fontsPkgs = import ./fonts.nix { inherit pkgs ttf-phosphor-icons; };
  tesseractPkgs = import ./tesseract.nix { inherit pkgs; };

  # NixOS-specific packages
  nixosPkgs = [
    pkgs.power-profiles-daemon
    pkgs.networkmanager
  ];

  # Non-NixOS packages
  nonNixosPkgs = [ ];

  # Combine all packages
  baseEnv = corePkgs
    ++ toolsPkgs
    ++ mediaPkgs
    ++ appsPkgs
    ++ fontsPkgs
    ++ tesseractPkgs
    ++ (if isNixOS then nixosPkgs else nonNixosPkgs);

  envAmbxst = pkgs.buildEnv {
    name = "Ambxst-env";
    paths = baseEnv;
  };

  launcher = pkgs.writeShellScriptBin "ambxst" ''
    ${lib.optionalString (!isNixOS) ''
      # On non-NixOS, use local build from ~/.local/bin
      export PATH="$HOME/.local/bin:$PATH"
    ''}

    export AMBXST_QS="${quickshellPkg}/bin/qs"

    # Set QML2_IMPORT_PATH to include modules from envAmbxst (like syntax-highlighting)
    export QML2_IMPORT_PATH="${envAmbxst}/lib/qt-6/qml:$QML2_IMPORT_PATH"
    export QML_IMPORT_PATH="$QML2_IMPORT_PATH"

    # Delegate execution to CLI
    exec ${self}/cli.sh "$@"
  '';

in pkgs.buildEnv {
  name = "Ambxst";
  paths = [ envAmbxst launcher ];
}
