{config, lib, pkgs, ...}:

let
  cfg = config.host.application.rclone;
in
  with lib;
{
  options = {
    host.application.rclone = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables rclone";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rclone
    ];
  };
}