{config, lib, pkgs, ...}:

let
  container_name = "postfix-relay";
  container_description = "Enables Postfix mail relay container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/postfix";
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
      ports = {
        smtp = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable SMTP port binding with network detection";
          };
          host = mkOption {
            default = 25;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 25;
            type = with types; int;
            description = "Container port for SMTP";
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
        submission = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable submission port binding with network detection";
          };
          host = mkOption {
            default = 587;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 587;
            type = with types; int;
            description = "Container port for submission";
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
        registry = mkDefault cfg.image.registry.host;
        pullOnStart = mkDefault cfg.image.update;
      };

      resources = {
        memory = {
          max = mkDefault "256M";
        };
      };

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/var/log/postfix";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/data";
          target = "/data";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
      ];

      environment = {
        "TIMEZONE" = mkDefault config.time.timeZone;
        "CONTAINER_NAME" = mkDefault "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = toString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = toString cfg.logship;

        "MODE" = mkDefault "RELAY";
        "SERVER_NAME" = mkDefault "${config.host.network.hostname}.${config.host.network.domainname}";
      };

      ports =
        (if cfg.ports.smtp.enable then [
          {
            host = toString cfg.ports.smtp.host;
            container = toString cfg.ports.smtp.container;
            method = cfg.ports.smtp.method;
            excludeInterfaces = cfg.ports.smtp.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.smtp.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.smtp.zerotierNetwork;
          }
        ] else []) ++
        (if cfg.ports.submission.enable then [
          {
            host = toString cfg.ports.submission.host;
            container = toString cfg.ports.submission.container;
            method = cfg.ports.submission.method;
            excludeInterfaces = cfg.ports.submission.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.submission.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.submission.zerotierNetwork;
          }
        ] else []);

      secrets = {
        enable = mkDefault cfg.secrets.enable;
        autoDetect = mkDefault cfg.secrets.autoDetect;
        files = mkDefault cfg.secrets.files;
      };

      networking = {
        networks = [ "services" ];
      };
    };
  };
}