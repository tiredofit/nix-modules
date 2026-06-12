{config, lib, pkgs, ...}:

let
  cfg = config.host.application.util-linux;
in
  with lib;
{
  options = {
    host.application.util-linux = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables util-linux";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      util-linux
    ];
  };
}