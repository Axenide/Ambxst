# Media packages: video, audio, players
{ pkgs }:

with pkgs; [
  gpu-screen-recorder
  mpvpaper

  ffmpeg
  x264
  playerctl

  # Audio
  pipewire
  wireplumber
]
