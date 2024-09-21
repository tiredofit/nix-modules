{config, lib, pkgs, ...}:

let
  cfg = config.host.application.e2fsprogs;
in
  with lib;
{
  options = {
    host.application.e2fsprogs = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables e2fsprogs";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      e2fsprogs
    ];
  };
}