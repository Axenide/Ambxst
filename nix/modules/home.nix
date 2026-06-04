{ config, lib, ... }:

let
  cfg = config.programs.ambxst;
in {
  options.programs.ambxst = {
    enable = lib.mkEnableOption "Ambxst shell";

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      example = lib.literalExpression ''
        {
          bar = {
            position = "top";
            use12hFormat = true;
          };
          theme = {
            roundness = 8;
            font = "Roboto";
          };
          compositor = {
            gapsIn = 4;
            blurEnabled = true;
          };
        }
      '';
      description = ''
        Declarative Ambxst configuration. Each attribute name corresponds to a
        configuration module and its value is written as JSON to
        ''${XDG_CONFIG_HOME}/ambxst/config/<name>.json.

        Available modules: bar, theme, system, compositor, performance,
        weather, desktop, lockscreen, prefix, dock, ai, workspaces,
        notch, overview.

        Note: declared files are managed as read-only symlinks into the Nix
        store. The GUI settings menu cannot persist changes to managed files.
        Undeclared modules continue to use their GUI-editable defaults.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = lib.mapAttrs' (name: value:
      lib.nameValuePair "ambxst/config/${name}.json" {
        text = builtins.toJSON value;
        onChange = ''
          if [ -f /tmp/ambxst.pid ] && kill -0 "$(cat /tmp/ambxst.pid 2>/dev/null)" 2>/dev/null; then
            ambxst reload
          fi
        '';
      }
    ) cfg.settings;
  };
}
