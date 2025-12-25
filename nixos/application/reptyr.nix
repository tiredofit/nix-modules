{config, lib, pkgs, ...}:

let
  cfg = config.host.application.reptyr;
in
  with lib;
{
  options = {
    host.application.reptyr = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Reparent a running program to a new terminal";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      reptyr
    ];
  };
}