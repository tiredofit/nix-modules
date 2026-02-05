{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.gamecontroller;
in
  with lib;
{
  options = {
    host.hardware.gamecontroller = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Game Controller support";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      udev = {
        packages = with pkgs; [
          game-devices-udev-rules
        ];
        extraRules = ''
          KERNEL=="hidraw*", ATTRS{idVendor}=="2dc8", MODE="0660", GROUP="input", TAG+="uaccess"
          KERNEL=="hidraw*", KERNELS=="*2DC8:*", MODE="0660", GROUP="input", TAG+="uaccess"
        '';
      };
    };
  };
}
