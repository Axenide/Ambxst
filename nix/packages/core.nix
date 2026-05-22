# Core packages: Wayland, Mesa, Qt6
{ pkgs, quickshellPkg }:

with pkgs; [
  quickshellPkg

  # Graphics/Wayland
  mesa
  libglvnd
  egl-wayland
  wayland

  # Qt6
  qt6.qtbase
  qt6.qtsvg
  qt6.qttools
  qt6.qtwayland
  qt6.qtdeclarative
  qt6.qtimageformats
  kdePackages.qtmultimedia
  kdePackages.qtshadertools
  kdePackages.syntax-highlighting
]
