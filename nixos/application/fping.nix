{config, lib, pkgs, ...}:

let
  cfg = config.host.application.fping;
in
  with lib;
{
  options = {
    host.application.fping = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables fping";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      unstable.fping
    ];
  };
}