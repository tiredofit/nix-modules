{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.fingerprint;
in
  with lib;
{
  options = {
    host.hardware.fingerprint = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable fingerprint support";
      };
      touch = {
        enable = mkOption {
          default = true;
          type = with types; bool;
          description = "Enable touch module support";
        };
        driver = mkOption {
          default = pkgs.libfprint-2-tod1-goodix-550a;
          type = with types; package;
          description = "Touch Driver";
        };
      };
      service.enable = mkOption {
        default = true;
        type = with types; bool;
        description = "Auto start service";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      fprintd = {
        enable = cfg.service.enable;
        tod = {
          enable = cfg.touch.enable;
          driver = cfg.touch.driver;
        };
      };
    };

    host.filesystem.impermanence.directories = mkIf config.host.filesystem.impermanence.enable [
      "/var/lib/fprint"
    ];
  };
}
