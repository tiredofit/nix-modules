{config, lib, pkgs, ...}:

let
  container_name = "clamav";
  container_description = "Enables Antivirus scanning container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/clamav";
  container_image_tag = "latest";
  cfg = config.host.container.${container_name};
  hostname = config.host.network.hostname;
  activationScript = "system.activationScripts.docker_${container_name}";
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
        tcp = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable ClamAV daemon port binding with network detection";
          };
          host = mkOption {
            default = 3310;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 3310;
            type = with types; int;
            description = "Container port for ClamAV daemon";
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
      hostname = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Custom hostname for the container (overrides default if set)";
      };
      containerName = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Custom container name (overrides default if set)";
      };
    };
  };

  config = mkIf cfg.enable {
    host.feature.virtualization.docker.containers."${container_name}" = {
      enable = mkDefault true;
      containerName = mkDefault (if cfg.containerName != null then cfg.containerName else "${container_name}");
      hostname = mkDefault cfg.hostname;

      image = {
        name = mkDefault cfg.image.name;
        tag = mkDefault cfg.image.tag;
        registry = mkDefault cfg.image.registry.host;
        pullOnStart = mkDefault cfg.image.update;
      };

      resources = {
        memory = {
          max = mkDefault "2.5G";
        };
      };

      ports = if cfg.ports.tcp.enable then [
        {
          host = toString cfg.ports.tcp.host;
          container = toString cfg.ports.tcp.container;
          method = cfg.ports.tcp.method;
          excludeInterfaces = cfg.ports.tcp.excludeInterfaces;
          excludeInterfacePattern = cfg.ports.tcp.excludeInterfacePattern;
          zerotierNetwork = cfg.ports.tcp.zerotierNetwork;
        }
      ] else [];

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/data/clamav";
          target = "/data";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/logs";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
      ];

      environment = {
        "TIMEZONE" = "${config.time.timeZone}";
        "CONTAINER_NAME" = "${config.host.network.hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = boolToString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = boolToString cfg.logship;

        "LISTEN_PORT" = toString cfg.ports.tcp.container;
        "DEFINITIONS_UPDATE_FREQUENCY" = "60";
        "ENABLE_ALERT_OLE2_MACROS" = "TRUE";
        "ENABLE_DETECT_PUA" = "FALSE";
        "EXCLUDE_PUA" = "Packed,NetTool,PWTool";
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
          extra = mkDefault (
            let
              rawName = if cfg.containerName != null then cfg.containerName else "${container_name}";
              aliasName = lib.strings.removeSuffix "-app" rawName;
              hostAlias = config.host.network.hostname.${aliasName} or null;
              aliasesList = [
                aliasName
              ] ++ (lib.optional (hostAlias != null) hostAlias) ++ [
                  "clamav"
                ];
            in
              aliasesList ++ (cfg.networking.aliases.extra or [])
          );
        };
      };
    };
  };
}