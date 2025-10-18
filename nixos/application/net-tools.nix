{config, lib, pkgs, ...}:

let
  cfg = config.host.application.net-tools;
in
  with lib;
{
  options = {
    host.application.net-tools = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables Net-Tools";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      net-tools
    ];
  };
}