{config, lib, pkgs, ...}:

let
  cfg = config.host.application.rsync;
in
  with lib;
{
  options = {
    host.application.rsync = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables remote syncing tool";
      };
    };
  };

  config = mkIf cfg.enable (let
    aliases = {
      rsync = "rsync -aXxtv";
    };
  in {
      environment.systemPackages = with pkgs; [
        rsync
      ];

      programs = {
        bash = {
          shellAliases = aliases;
        };
        zsh = {
          shellAliases = aliases;
        };
      };
  });
}