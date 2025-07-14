{config, lib, pkgs, ...}:

let
  container_name = "fluent-bit";
  container_description = "Enables log shipping container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/alpine";
  container_image_tag = "3.21";
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
        };
      };
      ports = {
        forward = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable Fluent Bit forward port binding with network detection";
          };
          host = mkOption {
            default = 24224;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 24224;
            type = with types; int;
            description = "Container port for Fluent Bit forward";
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
        pullOnStart = mkDefault cfg.image.update;
        registry = mkDefault cfg.image.registry.host;
      };

      resources = {
        memory = {
          max = mkDefault "1024M";
        };
      };

      ports = if cfg.ports.forward.enable then [
        {
          host = toString cfg.ports.forward.host;
          container = toString cfg.ports.forward.container;
          method = cfg.ports.forward.method;
          excludeInterfaces = cfg.ports.forward.excludeInterfaces;
          excludeInterfacePattern = cfg.ports.forward.excludeInterfacePattern;
          zerotierNetwork = cfg.ports.forward.zerotierNetwork;
        }
      ] else [];

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/var/log/fluentbit";
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

        "FLUENTBIT_MODE" = mkDefault "FORWARD";
        "FLUENTBIT_FORWARD_PORT" = toString cfg.ports.forward.container;
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
        aliases = {
          default = mkDefault true;
          extra = mkDefault [
            "fluent-proxy"
          ];
        };
      };
    };
  };
}