{config, lib, pkgs, ...}:

let
  container_name = "s3ql";
  container_description = "Enables S3QL filesystem container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/s3ql";
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

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/config";
          target = "/config";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/cache";
          target = "/cache";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;  # Cache performance
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/logs";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/mnt/${container_name}";
          target = "/data";
          options = "shared";
          createIfMissing = mkDefault false;  # Mount point
        }
      ];

      environment = {
        "TIMEZONE" = mkDefault config.time.timeZone;
        "CONTAINER_NAME" = mkDefault "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = toString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = toString cfg.logship;
      };

      secrets = {
        enable = mkDefault true;
        autoDetect = mkDefault true;
      };

      # Security options for filesystem functionality
      privileged = mkDefault true;

      capabilities = {
        add = [
          "SYS_ADMIN"
        ];
      };

      devices = [
        {
          host = "/dev/net/tun";
          container = "/dev/net/tun";
          permissions = "rwm";
        }
      ];

      networking = {
        networks = [
          "services"
        ];
      };
    };
  };
}