{config, lib, pkgs, ...}:
let
  cfg = config.host.feature.graphics.windowManager;
in
  with lib;
{
  imports = [
    ./hyprland.nix
  ];

  options = {
    host.feature.graphics.windowManager = {
      manager = mkOption {
        type = types.listOf (types.enum ["cinnamon" "cosmic" "hyprland" "niri" "sway"]);
        default = [];
        description = "List of window managers / desktop environments to enable";
      };
    };
  };
}
