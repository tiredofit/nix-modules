{config, lib, pkgs, ...}:

let
  cfg = config.host.application.zoxide;
in
  with lib;
{
  options = {
    host.application.zoxide = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables zoxide";
      };
    };
  };

  config = mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
    };
  };
}