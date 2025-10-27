{config, lib, pkgs, ...}:
let
  cfg = config.host.network.manager;
in
  with lib;
{
  options = {
    host.network.manager = mkOption {
      type = types.enum ["networkmanager" "systemd-networkd" "both"];
      default = null;
      description = "Network Manager";
    };
  };

  config = {
    host.filesystem.impermanence.directories = mkIf (config.host.filesystem.impermanence.enable) (
      [
      ] ++
      (if (cfg == "networkmanager" || cfg == "both") then [
        "/etc/NetworkManager"
        "/var/lib/NetworkManager"
      ] else [])
    );

    networking = {
      dhcpcd.enable = mkForce false;
      useNetworkd = mkForce false;
      networkmanager = {
        enable = mkForce (cfg == "networkmanager" || cfg == "both");
        wifi.backend = config.host.hardware.wireless.backend;
      };
      wireless = mkIf (cfg == "networkmanager" || cfg == "both") {
        enable = mkForce false;
        #iwd.enable = mkForce false;
      };
    };

    services = {
      resolved = {
        enable = mkDefault true;
      };
    };

    systemd = {
      network.enable = mkDefault (cfg == "systemd-networkd" || cfg == "both");
      services = {
        systemd-networkd-wait-online.enable = if (cfg == "systemd-networkd" || cfg == "both") then pkgs.lib.mkForce false else mkDefault (cfg == "systemd-networkd" || cfg == "both");
        systemd-networkd.stopIfChanged = if (cfg == "systemd-networkd" || cfg == "both") then pkgs.lib.mkForce false else false;
        systemd-resolved.stopIfChanged = false;
        NetworkManager-wait-online.enable = mkIf (cfg == "networkmanager" || cfg == "both") false;
      };
    };
  };
}
