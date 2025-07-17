{config, lib, pkgs, ...}:

let
  cfg = config.host.application.direnv;
in
  with lib;
{
  options = {
    host.application.direnv = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables direnv";
      };
    };
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
    };
  };
}