# System tools and utilities
{ pkgs }:

with pkgs; [
  brightnessctl
  curl
  ddcutil
  fontconfig
  glib
  grim
  imagemagick
  jq

  libnotify
  matugen
  python3
  power-profiles-daemon
  slurp
  sqlite
  upower
  wl-clip-persist
  wl-clipboard
  wlsunset
  wtype
  xdg-utils
  zbar
  zenity
  inetutils
  adw-gtk3

   # Fingerprint authentication
   fprintd
   pam
   python3Packages.dbus-python
   python3Packages.cryptography
  ]
