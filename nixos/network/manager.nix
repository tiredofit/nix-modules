{config, lib, pkgs, ...}:
let
  rawCfg = config.host.network.manager;
  cfg = if rawCfg == "networkd" then "systemd-networkd" else rawCfg;
in
  with lib;
{
  options = {
    host.network.manager = mkOption {
      type = types.enum ["networkmanager" "networkd" "systemd-networkd" "both"];
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
      networkmanager.enable = mkDefault (cfg == "networkmanager" || cfg == "both");
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
