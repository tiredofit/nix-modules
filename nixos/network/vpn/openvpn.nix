{config, lib, pkgs, ...}:

let
  cfg = config.host.network.vpn.openvpn;
in
  with lib;
{
  options = {
    host.network.vpn.openvpn = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables OpenVPN functionality";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      openvpn
    ];

    networking.networkmanager.plugins = mkIf (config.networking.networkmanager.enable) (with pkgs; [
      networkmanager-openvpn
    ]);
  };
}