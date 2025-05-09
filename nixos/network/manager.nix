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
    networking = {
      networkmanager = mkIf (cfg == "networkmanager") {
        enable = true;
      };
    };

    host.filesystem.impermanence.directories = mkIf (config.host.filesystem.impermanence.enable) (
      [
        # Always include these directories if impermanence is enabled
      ] ++
      (if cfg == "networkmanager" then [
        "/etc/NetworkManager"
        "/var/lib/NetworkManager"
      ] else [])
    );

    services = {
      resolved = {
        enable = mkDefault true;
      };
    };
  };
}
