{config, lib, pkgs, ...}:

let
  cfg = config.host.application.ripgrep;
in
  with lib;
{
  options = {
    host.application.ripgrep = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables ripgrep";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ripgrep
    ];
  };
}