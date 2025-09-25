{config, lib, pkgs, ...}:

let
  cfg = config.host.application.lnav;
in
  with lib;
{
  options = {
    host.application.lnav = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables log navigator";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      lnav
    ];
  };
}