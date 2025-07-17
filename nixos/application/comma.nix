{config, lib, pkgs, ...}:

let
  cfg = config.host.application.comma;
in
  with lib;
{
  options = {
    host.application.comma = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables comma";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      comma
    ];
  };
}