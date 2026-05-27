# NixOS module for Ambxst
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ambxst;
in {
  options.programs.ambxst = {
    enable = lib.mkEnableOption "Ambxst shell";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The Ambxst package to use";
    };

    fonts.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install Ambxst fonts (including Phosphor Icons)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Register fonts with fontconfig (NixOS handles this via fonts.packages)
    fonts.packages = lib.mkIf cfg.fonts.enable (with pkgs; [
      roboto
      roboto-mono
      league-gothic
      terminus_font
      terminus_font_ttf
      dejavu_fonts
      liberation_ttf
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      (pkgs.callPackage ../packages/phosphor-icons.nix { })
    ]);

    # Enable recommended services for full functionality
    services.upower.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    programs.gpu-screen-recorder.enable = lib.mkDefault true;
    networking.networkmanager.enable = lib.mkDefault true;
  };
}
