{config, lib, pkgs, ...}:

let
  cfg = config.host.service.syncthing;
in
  with lib;
{
  options = {
    host.service.syncthing = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables Syncthing";
      };
      openFirewall = {
        enable = mkOption {
          default = true;
          type = with types; bool;
          description = "Open Syncthing ports in the firewall";
        };
        tcpPorts = mkOption {
            default = [ ];
            type = with types; listOf types.int;
            description = "List of TCP ports to allow";
          };
        udpPorts = mkOption {
          default = [ ];
          type = with types; listOf types.int;
          description = "List of UDP ports to allow";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      syncthing = {
        enable = true;
      };
    };

    networking = mkIf cfg.openFirewall.enable {
      firewall = {
        allowedTCPPorts = mkIf (cfg.openFirewall.tcpPorts != []) cfg.openFirewall.tcpPorts;
        allowedUDPPorts = mkIf (cfg.openFirewall.udpPorts != []) cfg.openFirewall.udpPorts;
      };
    };

    host = {
      filesystem = {
        impermanence.directories = mkIf config.host.filesystem.impermanence.enable [
            "/var/lib/syncthing"
          ];
      };
    };
  };
}
