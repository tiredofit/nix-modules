{config, lib, pkgs, ...}:

let
  container_name = "traefik-internal";
  container_description = "Enables reverse proxy container";
  container_image_registry = "docker.io";
  container_image_name = "tiredofit/traefik";
  container_image_tag = "3.3";

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
        default = "true";
        type = with types; str;
        description = "Enable monitoring for this container";
      };
      monitor = mkOption {
        default = "true";
        type = with types; str;
        description = "Enable monitoring for this container";
      };
    };
  };

  config = mkIf cfg.enable {
    host.feature.virtualization.docker.containers."${container_name}" = {
      image = "${cfg.image.name}:${cfg.image.tag}";
      labels = {
        "traefik.proxy.visibility" = "internal";
      };
      #ports = [ ## We're already binding this and we want it to be accesible from our internal network.
      #  "80:80"
      #  "443:443"
      #];
      volumes = [
        "/var/local/data/_system/${container_name}/certs:/data/certs"
        "/var/local/data/_system/${container_name}/config:/data/config"
        "/var/local/data/_system/${container_name}/logs:/data/logs"
      ];
      environment = {
        "TIMEZONE" = "America/Vancouver";
        "CONTAINER_NAME" = "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = cfg.logship;

        "DOCKER_ENDPOINT" = "http://socket-proxy:2375";
        "LOG_LEVEL" = "WARN";
        "ACCESS_LOG_TYPE" = "FILE";
        "LOG_TYPE" = "FILE";
        "TRAEFIK_USER" = "traefik";
        "LETSENCRYPT_CHALLENGE" = "DNS";
        "LETSENCRYPT_DNS_PROVIDER" = "cloudflare";
        "DOCKER_CONTEXT" = "Label(`traefik.proxy.visibility`, `internal`)"
        "DOCKER_DEFAULT_NETWORK" = "proxy-internal";
        #"LETSENCRYPT_EMAIL" = "common_env";                                            # hosts/common/secrets/container-internal.env
        #"CF_API_EMAIL" = "1234567890";                                                 # hosts/common/secrets/container-internal.env
        #"CF_API_KEY" = "1234567890";                                                   # hosts/common/secrets/container-internal.env
        "DASHBOARD_HOSTNAME" = "${hostname}.i.${config.host.network.domainname}";       # hosts/common/secrets/container-internal.env
      };
      environmentFiles = [
        config.sops.secrets."common-container-${container_name}".path
      ];
      extraOptions = [
        "--hostname=${hostname}.vpn.${config.host.network.domainname}"
        "--cpus=0.5"
        "--memory=512M"
        "--network-alias=${hostname}-${container_name}"
      ];
      networks = [
        "services"      # Make this the first network
        "proxy-internal"
        "socket-proxy"
      ];
      autoStart = mkDefault true;
      log-driver = mkDefault "local";
      login = {
        registry = cfg.image.registry.host;
      };
    };

    sops.secrets = {
      "common-container-${container_name}" = {
        format = "dotenv";
        sopsFile = "${config.host.configDir}/hosts/common/secrets/container/container-${container_name}.env";
        restartUnits = [ "docker-${container_name}.service" ];
      };
    };

    systemd.services."docker-${container_name}" = {
      after = lib.mkIf services.zerotierone.enable [ "zerotierone.service" ];
      preStart = ''
        if [ ! -d /var/local/data/_system/${container_name}/logs ]; then
            mkdir -p /var/local/data/_system/${container_name}/logs
            ${pkgs.e2fsprogs}/bin/chattr +C /var/local/data/_system/${container_name}/logs
        fi
      '';
      serviceConfig = {
        StandardOutput = "null";
        StandardError = "null";
      };
    };
  };
}