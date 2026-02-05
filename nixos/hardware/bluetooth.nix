{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.bluetooth;
in
  with lib;
{
  options = {
    host.hardware.bluetooth = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Bluetooth";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      extraModulePackages = with config.boot.kernelPackages; [ ];
      extraModprobeConfig = ''
        options bluetooth disable_ertm=Y
      '';
    };

    environment.systemPackages = with pkgs; [
      bluetuith
    ];

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = mkDefault true;
      disabledPlugins = mkDefault ["sap"];
      settings = {
        General = {
          Class = mkDefault "0x000100";
          Experimental = mkDefault true;
          FastConnectable = mkDefault true;
          JustWorksRepairing = mkDefault "always";
        };
      };
    };

    host.filesystem.impermanence.directories = mkIf config.host.filesystem.impermanence.enable [
      "/var/lib/bluetooth"
    ];

    services = {
      blueman.enable = mkDefault true;
    };
  };
}
