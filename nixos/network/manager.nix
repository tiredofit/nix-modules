{config, lib, pkgs, ...}:
let
  rawCfg = config.host.network.manager;
  cfg = if rawCfg == "networkd" then "systemd-networkd" else rawCfg;
in
  with lib;
{
  options = {
    host.network.manager = mkOption {
      type = types.enum ["networkmanager" "networkd" "systemd-networkd"];
      default = null;
      description = "Network Manager";
    };
  };

  config = {
    host.filesystem.impermanence.directories = mkIf (config.host.filesystem.impermanence.enable) (
      [
      ] ++
      (if cfg == "networkmanager" then [
        "/etc/NetworkManager"
        "/var/lib/NetworkManager"
      ] else [])
    );

    networking = {
      useNetworkd = mkDefault (cfg == "systemd-networkd");
      networkmanager.enable = mkDefault (cfg == "networkmanager");
    };

    services = {
      resolved = {
        enable = mkDefault true;
      };
    };

    systemd = {
      network.wait-online.enable =  mkIf (cfg == "systemd-networkd") false;
      services = {
        systemd-networkd-wait-online.enable = if cfg == "systemd-networkd" then pkgs.lib.mkForce false else mkDefault (cfg == "systemd-networkd");
        systemd-networkd.stopIfChanged = if cfg == "systemd-networkd" then pkgs.lib.mkForce false else false;
        systemd-resolved.stopIfChanged = false;
        NetworkManager-wait-online.enable = mkIf (cfg == "networkmanager") false;
      };
    };
  };
}
