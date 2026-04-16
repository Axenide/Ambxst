# Media packages: video, audio, players
{ pkgs }:

with pkgs; [
  gpu-screen-recorder

  # GStreamer backend for QtMultimedia
  gst_all_1.gstreamer
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-good
  gst_all_1.gst-plugins-bad
  gst_all_1.gst-plugins-ugly
  gst_all_1.gst-libav

  ffmpeg
  x264
  playerctl

  # Audio
  pipewire
  wireplumber
]
