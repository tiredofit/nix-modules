{config, lib, pkgs, ...}:
let
  cfg = config.host.network.manager;
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
        # Always include these directories if impermanence is enabled
      ] ++
      (if cfg == "networkmanager" then [
        "/etc/NetworkManager"
        "/var/lib/NetworkManager"
      ] else [])
    );

    networking = {
      networkmanager = mkIf (cfg == "networkmanager") {
        enable = true;
      };
    };

    services = {
      resolved = {
        enable = mkDefault true;
      };
    };

    # https://github.com/systemd/systemd/blob/e1b45a756f71deac8c1aa9a008bd0dab47f64777/NEWS#L13
    systemd.services.NetworkManager-wait-online.enable = mkIf (cfg == "networkmanager") false;
    systemd.network.wait-online.enable =  mkIf (cfg == "systemd-networkd") false;

    # Do not take down the network for too long when upgrading,
    # This also prevents failures of services that are restarted instead of stopped.
    # It will use `systemctl restart` rather than stopping it with `systemctl stop`
    # followed by a delayed `systemctl start`.
    systemd.services.systemd-networkd.stopIfChanged = mkIf (cfg == "systemd-networkd") false;
    # Services that are only restarted might be not able to resolve when resolved is stopped before
    systemd.services.systemd-resolved.stopIfChanged = false;
  };
}
