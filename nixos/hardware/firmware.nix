{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.firmware;
in
  with lib;
{
  options = {
    host.hardware.firmware = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Firmware Updating support";
      };
      service.enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Auto start service";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      fwupd
    ];

    services = {
      fwupd = {
        enable = cfg.service.enable;
      };
    };
  };
}
