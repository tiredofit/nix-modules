{config, lib, pkgs, ...}:

let
  cfg = config.host.service.iodine;
in
  with lib;
{
  options = {
    host.service.iodine = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "DNS Tunnel";
      };
      config = mkOption {
        default = "";
        type = with types; str;
        description = "Extra configuration";
      };

      ip = mkOption {
        default = "10.23.23.1";
        type = with types; str;
        description = "Server IP Address";
      };
      port = mkOption {
        default = 53;
        type = with types; port;
        description = "Server port";
      };

    };
  };

  config = mkIf cfg.enable {
    services = {
      iodine = {
        server = {
          enable = true;
          extraConfig = cfg.config + " -p " + "${builtins.toString cfg.port} " + cfg.ip + " $(cat " + config.sops.secrets."iodine/domain".path + ")";
          passwordFile = config.sops.secrets."iodine/psk".path;
        };
      };
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.ip_forward" = 1;
    };
    networking.firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ cfg.port ];
    };

    sops.secrets = {
      "iodine/domain" = mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/iodine/iodine.yaml")  {
        sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/iodine/iodine.yaml" ;
      };
      "iodine/psk" = mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/iodine/iodine.yaml")  {
        sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/iodine/iodine.yaml" ;
      };
    };
  };
}