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
    #boot.kernelParams = ["btusb"];
    hardware.bluetooth = {
      enable = true;
      package = pkgs.bluez5-experimental;
      #hsphfpd.enable = true;
      powerOnBoot = true;
      disabledPlugins = ["sap"];
      settings = {
        General = {
          JustWorksRepairing = "always";
          MultiProfile = "multiple";
        };
      };
    };

    services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = mkIf (config.host.hardware.sound.enable && config.host.hardware.sound.server == "pipewire") {
      "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
      };
    };

    services.blueman.enable = true;

    host.filesystem.impermanence.directories = mkIf config.host.filesystem.impermanence.enable [
      "/var/lib/bluetooth"               # Bluetooth
    ];
  };
}
