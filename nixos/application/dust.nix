{config, lib, pkgs, ...}:

let
  cfg = config.host.application.dust;
in
  with lib;
{
  options = {
    host.application.dust = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables graphical disk usage";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (if lib.versionAtLeast lib.version "25.11pre" then dust else du-dust)
    ];
  };
}
