{config, lib, pkgs, ...}:

let
  container_name = "llng-handler";
  container_description = "Enables LemonLDAP-NG authentication handler container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/lemonldap";
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
      ports = {
        llng = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable LemonLDAP-NG handler port binding with network detection";
          };
          host = mkOption {
            default = 2884;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 2884;
            type = with types; int;
            description = "Container port for LemonLDAP-NG handler socket";
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
        memory = {
          max = mkDefault "512M";
        };
      };

      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${hostname}-llng-handler.rule" = "Host(`${hostname}.handler.auth.${config.host.network.domainname}`)";
        "traefik.http.services.${hostname}-llng-handler.loadbalancer.server.port" = "${toString cfg.ports.llng.container}";
        "traefik.proxy.visibility" = "public";
      };

      ports = if cfg.ports.llng.enable then [
        {
          host = toString cfg.ports.llng.host;
          container = toString cfg.ports.llng.container;
          method = cfg.ports.llng.method;
          excludeInterfaces = cfg.ports.llng.excludeInterfaces;
          excludeInterfacePattern = cfg.ports.llng.excludeInterfacePattern;
        }
      ] else [];

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/www/logs";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/config";
          target = "/etc/lemonldap-ng";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
      ];

      environment = {
        "TIMEZONE" = mkDefault config.time.timeZone;
        "CONTAINER_NAME" = mkDefault "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = toString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = toString cfg.logship;

        "MODE" = mkDefault "HANDLER";
        "HANDLER_SOCKET_TCP_PORT" = toString cfg.ports.llng.container;
        "LLNG_DOMAIN" = mkDefault config.host.network.domainname;
      };

      secrets = {
        enable = mkDefault true;
        autoDetect = mkDefault true;
      };

      networking = {
        networks = [
          "services"
          "proxy"
        ];
      };
    };
  };
}