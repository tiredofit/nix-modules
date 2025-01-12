{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.backlight;
in
  with lib;
{
  options = {
    host.hardware.backlight = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables tools for display backlight control";
      };
      keys = {
        down = mkOption {
          default = 224;
          type = with types; int;
          description = "Key to increase brightness";
        };
        up = mkOption {
          default = 225;
          type = with types; int;
          description = "Key to increase brightness";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    programs.light.enable = true;
    services.actkbd = {
      enable = true;
      bindings = [
        { keys = [ cfg.keys.up ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -A 10"; }
        { keys = [ cfg.keys.down ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -U 10"; }
      ];
    };
  };
}
