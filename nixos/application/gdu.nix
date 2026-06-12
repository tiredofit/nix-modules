{config, lib, pkgs, ...}:

let
  cfg = config.host.application.gdu;
in
  with lib;
{
  options = {
    host.application.gdu = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables graphical disk usage";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gdu
    ];
  };
}
