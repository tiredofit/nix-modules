{config, lib, pkgs, ...}:

let
  container_name = "traefik";
  container_description = "Enables Traefik reverse proxy container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/traefik";
  container_image_tag = "3.4";
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
          default = true;
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
        };
      };
      docker = {
        context = mkOption {
          default = "Label(`traefik.proxy.visibility`, `public`)";
          type = with types; str;
          description = "Docker context filter for Traefik service discovery";
        };
        endpoint = mkOption {
          default = if config.host.container.socket-proxy.enable then "http://socket-proxy:2375" else "unix:///var/run/docker.sock";
          type = with types; str;
          description = "Docker API endpoint (socket-proxy when enabled, unix socket when disabled)";
        };
      };
      ports = {
        http = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable HTTP port binding with network detection";
          };
          host = mkOption {
            default = 80;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 80;
            type = with types; int;
            description = "Container port for HTTP protocol";
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
        };
        https = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable HTTPS port binding with network detection";
          };
          host = mkOption {
            default = 443;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 443;
            type = with types; int;
            description = "Container port for HTTPS protocol";
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
        };
        http3 = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable HTTP/3 (UDP) port binding with network detection";
          };
          host = mkOption {
            default = 443;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 443;
            type = with types; int;
            description = "Container port for HTTP3 protocol";
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
        };
      };
    };
  };

  config = mkIf cfg.enable {
    host.feature.virtualization.docker.containers."${container_name}" = {
      enable = mkDefault true;
      containerName = mkDefault "${config.host.network.hostname}-${container_name}";

      image = {
        name = mkDefault cfg.image.name;
        tag = mkDefault cfg.image.tag;
        registry = mkDefault cfg.image.registry.host;
        pullOnStart = mkDefault cfg.image.update;
      };

      resources = {
        cpus = mkDefault "0.5";
        memory = {
          max = mkDefault "512M";
        };
      };

      hostname = mkDefault "${hostname}.vpn.${config.host.network.domainname}";

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/certs";
          target = "/data/certs";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/config";
          target = "/data/config";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/data/logs";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
      ];

      environment = {
        "TIMEZONE" = mkDefault config.time.timeZone;
        "CONTAINER_NAME" = mkDefault "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = toString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = toString cfg.logship;

        "HTTP_LISTEN_PORT" = toString cfg.ports.http.container;
        "HTTPS_LISTEN_PORT" = toString cfg.ports.https.container;
        "HTTP3_LISTEN_PORT" = toString cfg.ports.http3.container;

        "DOCKER_ENDPOINT" = cfg.docker.endpoint;
        "LOG_LEVEL" = mkDefault "WARN";
        "ACCESS_LOG_TYPE" = mkDefault "FILE";
        "LOG_TYPE" = mkDefault "FILE";
        "TRAEFIK_USER" = mkDefault "traefik";
        "LETSENCRYPT_CHALLENGE" = mkDefault "DNS";
        "LETSENCRYPT_DNS_PROVIDER" = mkDefault "cloudflare";
        "DOCKER_CONTEXT" = cfg.docker.context;
        "DASHBOARD_HOSTNAME" = mkDefault "${hostname}.vpn.${config.host.network.domainname}";
      };

      labels = {
        "traefik.proxy.visibility" = "public";
      };

      ports =
        (if cfg.ports.http.enable then [
          {
            host = toString cfg.ports.http.host;
            container = toString cfg.ports.http.container;
            method = cfg.ports.http.method;
            excludeInterfaces = cfg.ports.http.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.http.excludeInterfacePattern;
          }
        ] else []) ++
        (if cfg.ports.https.enable then [
          {
            host = toString cfg.ports.https.host;
            container = toString cfg.ports.https.container;
            method = cfg.ports.https.method;
            excludeInterfaces = cfg.ports.https.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.https.excludeInterfacePattern;
          }
        ] else []) ++
        (if cfg.ports.http3.enable then [
          {
            host = toString cfg.ports.http3.host;
            container = toString cfg.ports.http3.container;
            protocol = "udp";
            method = cfg.ports.http3.method;
            excludeInterfaces = cfg.ports.http3.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.http3.excludeInterfacePattern;
          }
        ] else []);

      secrets = {
        enable = mkDefault cfg.secrets.enable;
        autoDetect = mkDefault cfg.secrets.autoDetect;
        files = mkDefault cfg.secrets.files;
      };

      networking = {
        networks = [
          "services"
          "proxy"
          "socket-proxy"
        ];
      };
    };
  };
}