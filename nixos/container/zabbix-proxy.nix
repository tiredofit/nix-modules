{config, lib, pkgs, ...}:

let
  container_name = "zabbix-proxy";
  container_description = "Enables Zabbix monitoring proxy container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/zabbix";
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
        proxy = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable Zabbix proxy port binding with network detection";
          };
          host = mkOption {
            default = 10051;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 10051;
            type = with types; int;
            description = "Container port for Zabbix Proxy";
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
          max = mkDefault "256M";
        };
      };

      ports = if cfg.ports.proxy.enable then [
        {
          host = toString cfg.ports.proxy.host;
          container = toString cfg.ports.proxy.container;
          method = cfg.ports.proxy.method;
          excludeInterfaces = cfg.ports.proxy.excludeInterfaces;
          excludeInterfacePattern = cfg.ports.proxy.excludeInterfacePattern;
        }
      ] else [];

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/var/log/zabbix/proxy";
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

        "ZABBIX_PROXY_HOSTNAME" = mkDefault "${hostname}-${container_name}";
        "ZABBIX_PROXY_LISTEN_PORT" = toString cfg.ports.proxy.container;
      };

      secrets = {
        enable = mkDefault true;
        autoDetect = mkDefault true;
      };

      networking = {
        networks = [ "services" ];
        dns = "172.19.153.53";  # Use unbound
      };
    };
  };
}