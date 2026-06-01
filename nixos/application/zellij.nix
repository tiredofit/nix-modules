{config, lib, pkgs, ...}:

let
  cfg = config.host.application.zellij;
in
  with lib;
{
  options = {
    host.application.zellij = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables terminal multiplexer";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      zellij
    ];
  };
}
