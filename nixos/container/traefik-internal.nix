{config, lib, pkgs, ...}:

let
  container_name = "traefik-internal";
  container_description = "Enables Traefik internal reverse proxy container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/traefik";
  container_image_tag = "3.5";
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
        constraint = mkOption {
          default = "Label(`traefik.proxy.visibility`, `internal`) || Label(`traefik.proxy.visibility`, `any`)";
          type = with types; str;
          description = "Docker constraint filter for Traefik service discovery";
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
            description = "Enable HTTP port binding with ZeroTier network detection";
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
            default = "zerotier";
            type = with types; enum [ "interface" "address" "pattern" "zerotier" ];
            description = "IP resolution method";
          };
          zerotierNetwork = mkOption {
            default = "";
            type = with types; str;
            description = "ZeroTier network ID";
          };
        };
        https = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable HTTPS port binding with ZeroTier network detection";
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
            default = "zerotier";
            type = with types; enum [ "interface" "address" "pattern" "zerotier" ];
            description = "IP resolution method";
          };
          zerotierNetwork = mkOption {
            default = "";
            type = with types; str;
            description = "ZeroTier network ID";
          };
        };
        http3 = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable HTTP/3 (UDP) port binding with ZeroTier network detection";
          };
          host = mkOption {
            default = 443;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 443;
            type = with types; int;
            description = "Container port for HTTP/3 (UDP) protocol";
          };
          method = mkOption {
            default = "zerotier";
            type = with types; enum [ "interface" "address" "pattern" "zerotier" ];
            description = "IP resolution method";
          };
          zerotierNetwork = mkOption {
            default = "";
            type = with types; str;
            description = "ZeroTier network ID";
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
          max = mkDefault "512M";
        };
      };

      hostname = mkDefault "${hostname}.internal.${config.host.network.domainname}";

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
        "CONTAINER_ENABLE_MONITORING" = boolToString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = boolToString cfg.logship;

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
        "LETSENCRYPT_DNS_RESOLVER" = "1.1.1.1:53,1.0.0.1:53";
        "DOCKER_CONSTRAINTS" = cfg.docker.constraint;
        "DASHBOARD_HOSTNAME" = mkDefault "${hostname}.internal.${config.host.network.domainname}";
      };

      secrets = {
        enable = mkDefault cfg.secrets.enable;
        autoDetect = mkDefault cfg.secrets.autoDetect;
        files = mkDefault cfg.secrets.files;
      };

      labels = {
        "traefik.proxy.visibility" = "internal";
      };

      ports =
        (if cfg.ports.http.enable then [
          {
            host = toString cfg.ports.http.host;
            container = toString cfg.ports.http.container;
            method = cfg.ports.http.method;
            zerotierNetwork = cfg.ports.http.zerotierNetwork;
          }
        ] else []) ++
        (if cfg.ports.https.enable then [
          {
            host = toString cfg.ports.https.host;
            container = toString cfg.ports.https.container;
            method = cfg.ports.https.method;
            zerotierNetwork = cfg.ports.https.zerotierNetwork;
          }
        ] else []) ++
        (if cfg.ports.http3.enable then [
          {
            host = toString cfg.ports.http3.host;
            container = toString cfg.ports.http3.container;
            protocol = "udp";
            method = cfg.ports.http3.method;
            zerotierNetwork = cfg.ports.http3.zerotierNetwork;
          }
        ] else []);

      networking = {
        networks = [
          "services"
          "proxy-internal"
          "socket-proxy"
        ];
        aliases = {
          default = mkDefault true;
          extra = mkDefault [ ];
        };
      };
    };
  };
}