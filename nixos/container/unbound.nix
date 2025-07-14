{config, lib, pkgs, ...}:

let
  container_name = "unbound";
  container_description = "Enables DNS resolver container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/unbound";
  container_image_tag = "latest";
  cfg = config.host.container.${container_name};
  hostname = config.host.network.hostname;
in
  with lib;
{
  options = {
    host.container.${container_name} = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = container_description;
      };
      image = {
        name = mkOption {
          default = container_image_name;
          type = with types; str;
          description = "Image name";
        };
        tag = mkOption {
          default = container_image_tag;
          type = with types; str;
          description = "Image tag";
        };
        registry = {
          host = mkOption {
            default = container_image_registry;
            type = with types; str;
            description = "Image Registry";
          };
        };
        update = mkOption {
          default = true;
          type = with types; bool;
          description = "Pull image on each service start";
        };
      };
      logship = mkOption {
        default = true;
        type = with types; bool;
        description = "Enable logshipping for this container";
      };
      monitor = mkOption {
        default = true;
        type = with types; bool;
        description = "Enable monitoring for this container";
      };
      secrets = {
        enable = mkOption {
          default = false;
          type = with types; bool;
          description = "Enable SOPS secrets for this container";
        };
        autoDetect = mkOption {
          default = true;
          type = with types; bool;
          description = "Automatically detect and include common secret files if they exist";
        };
        files = mkOption {
          default = [ ];
          type = with types; listOf str;
          description = "List of additional secret file paths to include";
          example = [
            "../secrets/unbound-config.env.enc"
          ];
        };
      };
      ports = {
        dns = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable DNS port binding with network detection";
          };
          host = mkOption {
            default = 53;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 53;
            type = with types; int;
            description = "Container port for DNS protocol";
          };
          protocol = mkOption {
            default = "udp";
            type = with types; enum [ "tcp" "udp" ];
            description = "Protocol for DNS (UDP for queries, TCP for large responses)";
          };
          method = mkOption {
            default = "interface";
            type = with types; enum [ "interface" "address" "pattern" "zerotier" ];
            description = "IP resolution method";
          };
          excludeInterfaces = mkOption {
            default = [ "lo" ];
            type = with types; listOf types.str;
            description = "Interfaces to exclude";
          };
          excludeInterfacePattern = mkOption {
            default = "docker|veth|br-|enp|eth|wlan";
            type = with types; str;
            description = "Interface exclusion pattern";
          };
          zerotierNetwork = mkOption {
            default = "";
            type = with types; str;
            description = "ZeroTier network ID";
          };
        };
        dns_tcp = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable DNS TCP port binding with network detection";
          };
          host = mkOption {
            default = 53;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 53;
            type = with types; int;
            description = "Container port for DNS TCP protocol";
          };
          protocol = mkOption {
            default = "tcp";
            type = with types; enum [ "tcp" "udp" ];
            description = "Protocol for DNS TCP (always TCP for zone transfers)";
          };
          method = mkOption {
            default = "interface";
            type = with types; enum [ "interface" "address" "pattern" "zerotier" ];
            description = "IP resolution method";
          };
          excludeInterfaces = mkOption {
            default = [ "lo" "zt0" ];
            type = with types; listOf types.str;
            description = "Interfaces to exclude";
          };
          excludeInterfacePattern = mkOption {
            default = "docker|veth|br-";
            type = with types; str;
            description = "Interface exclusion pattern";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    host.feature.virtualization.docker.containers."${container_name}" = {
      enable = mkDefault true;
      containerName = mkDefault "${container_name}";

      image = {
        name = mkDefault cfg.image.name;
        tag = mkDefault cfg.image.tag;
        registry = mkDefault cfg.image.registry.host;
        pullOnStart = mkDefault cfg.image.update;
      };

      resources = {
        cpus = mkDefault "0.5";
        memory = {
          max = mkDefault "256M";
          reserve = mkDefault "32M";
        };
      };

      ports =
        (if cfg.ports.dns.enable then [
          {
            host = toString cfg.ports.dns.host;
            container = toString cfg.ports.dns.container;
            protocol = cfg.ports.dns.protocol;
            method = cfg.ports.dns.method;
            excludeInterfaces = cfg.ports.dns.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.dns.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.dns.zerotierNetwork;
          }
        ] else []) ++
        (if cfg.ports.dns_tcp.enable then [
          {
            host = toString cfg.ports.dns_tcp.host;
            container = toString cfg.ports.dns_tcp.container;
            protocol = cfg.ports.dns_tcp.protocol;
            method = cfg.ports.dns_tcp.method;
            excludeInterfaces = cfg.ports.dns_tcp.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.dns_tcp.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.dns_tcp.zerotierNetwork;
          }
        ] else []);

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/logs";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
      ];

      environment = {
        "TIMEZONE" = mkDefault config.time.timeZone;
        "CONTAINER_NAME" = mkDefault "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = boolToString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = boolToString cfg.logship;

        "LISTEN_PORT" = toString cfg.ports.dns.container;
        "ENABLE_IPV6" = mkDefault "FALSE";
      };

      secrets = {
        enable = mkDefault cfg.secrets.enable;
        autoDetect = mkDefault cfg.secrets.autoDetect;
        files = mkDefault cfg.secrets.files;
      };

      networking = {
        networks = [
          "services"
        ];
        ip = mkDefault "172.19.153.53";  # Fixed IP for DNS
        aliases = {
          default = mkDefault true;
          extra = mkDefault [
            "${container_name}-app"
          ];
        };
      };
    };
  };
}