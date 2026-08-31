# Applications: terminal, launcher, control panels
{ pkgs }:

with pkgs; [
  # Terminal — none by default; user configures their preferred terminal in
  # ~/.config/ambxst/config/general.json (Config.general.terminal)
  tmux

  # Launcher
  fuzzel

  # Control panels
  networkmanagerapplet
  blueman
  pavucontrol
  easyeffects
  gradia

  # Icons
  kdePackages.breeze-icons
  hicolor-icon-theme
]
