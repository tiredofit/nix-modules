{config, lib, pkgs, ...}:

let
  container_name = "cloudflare-companion";
  container_description = "Enables ability to create CNAMEs with traefik container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/traefik-cloudflare-companion";
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
        cpus = mkDefault "0.25";
        memory = {
          max = mkDefault "128M";
        };
      };

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/logs";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
      ];

      environment = {
        "TIMEZONE" = mkDefault config.time.timeZone;
        "CONTAINER_NAME" = mkDefault "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = toString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = toString cfg.logship;

        "DOCKER_HOST" = "http://socket-proxy:2375";
        "TRAEFIK_VERSION" = "2";
        "TARGET_DOMAIN" = "${hostname}.${config.host.network.domainname}";

        #"CF_EMAIL" = "email@example.com";  # hosts/common/secrets/container-traefik-cloudflare-companion.env
        #"CF_TOKEN" = "1234567890";         # hosts/common/secrets/container-traefik-cloudflare-companion.env

        #"DOMAIN1" = "example.com";         # hosts/common/secrets/container-traefik-cloudflare-companion.env
        #"DOMAIN1_ZONE_ID" = "abc";         # hosts/common/secrets/container-traefik-cloudflare-companion.env
      };

      labels = {
        "traefik.proxy.visibility" = "public";
      };

      ports = [];

      secrets = {
        enable = mkDefault cfg.secrets.enable;
        autoDetect = mkDefault cfg.secrets.autoDetect;
        files = mkDefault cfg.secrets.files;
      };

      networking = {
        networks = [
          "services"
          "socket-proxy"
        ];
      };
    };
  };
}