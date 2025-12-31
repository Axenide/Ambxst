# Applications: terminal, launcher, control panels
{ pkgs, ...}:

with pkgs; [
  # Terminal
  kitty
  tmux

  # Launcher
  fuzzel

  # Control panels
  networkmanagerapplet
  blueman
  pwvucontrol
  easyeffects

  # Icons
  kdePackages.breeze-icons
  hicolor-icon-theme
]
