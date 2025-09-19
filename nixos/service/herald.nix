{ config, inputs, lib, pkgs, ... }:
  let
    cfg = config.host.service.herald;
  in
    with lib;
{
    imports = [
      inputs.herald.nixosModules.default
    ];

    options = {
      host.service.herald = {
        enable = mkOption {
          default = false;
          type = with types; bool;
          description = "Manage DNS records based on DNS servers based on events from Docker, Traefik, Caddy or other providers.";
        };

        service = {
          enable = mkOption {
            default = true;
            type = with types; bool;
            description = "Auto start on server start";
          };
        };

        package = mkOption {
          type = with types; package;
          default = inputs.herald.packages.${pkgs.system}.herald;
          description = "Herald package to use.";
        };

        configFile = mkOption {
          type = with types; str;
          default = "herald.yml";
          description = "Path to the YAML configuration file";
        };

        defaults = mkOption {
          type = with types; attrsOf anything;
          default = {};
          description = "Default DNS record settings.";
        };

        general = mkOption {
          type = with types; attrsOf anything;
          default = {};
          description = "General application settings.";
        };

        inputs = mkOption {
          type = with types; attrsOf (attrsOf anything);
          default = {};
          example = {
            docker = {
              type = "docker";
              api_url = "unix:///var/run/docker.sock";
              api_auth_user = "";
              api_auth_pass = "";
              process_existing = false;
              expose_containers = false;
              swarm_mode = false;
              record_remove_on_stop = false;
              tls = {
                  verify = true;
                  ca = "/etc/docker/certs/ca.pem";
                  cert = "/etc/docker/certs/cert.pem";
                  key = "/etc/docker/certs/key.pem";
              };
            };
            traefik = {
              type = "traefik";
              api_url = "http://traefik:8080/api/http/routers";
              api_auth_user = "admin";
              api_auth_pass = "password";
              interval = "60s";
              record_remove_on_stop = true;
              process_existing = true;
            };
            caddy = {
              type = "caddy";
              api_url = "http://caddy:2019/config/";
              api_auth_user = "";
              api_auth_pass = "";
              interval = "60s";
              record_remove_on_stop = true;
              process_existing = true;
            };
            file = {
              type = "file";
              source = "/var/lib/herald/records.yaml";
              format = "yaml";
              interval = "-1";
              record_remove_on_stop = true;
              process_existing = true;
            };
            remote = {
              type = "remote";
              url = "https://example.com/records.yaml";
              format = "yaml";
              interval = "30s";
              process_existing = true;
              record_remove_on_stop = true;
              auth_user = "myuser";
              auth_pass = "mypassword";
            };
            tailscale = {
              type = "tailscale";
              api_key = "tskey-api-xxxxx";
              tailnet = "-";
              domain = "ts.example.com";
              interval = "120s";
              hostname_format = "simple";
              process_existing = true;
              record_remove_on_stop = true;
              filter = [
                {
                  type = "online";
                  conditions = [
                    {
                      value = "true";
                    }
                  ];
                }
              ];
            };
            zerotier = {
              type = "zerotier";
              api_url = "https://my.zerotier.com";
              api_token = "your_api_token";
              network_id = "your_network_id";
              domain = "zt.example.com";
              interval = "60s";
              online_timeout_seconds = 300;
              use_address_fallback = true;
              process_existing = true;
              record_remove_on_stop = true;
              filter = [
                {
                  type = "online";
                  conditions = [
                    {
                      value = "true";
                    }
                  ];
                }
              ];
            };
        };
        description = ''
          Input provider configurations for Docker, Traefik, File, Remote, etc.
        '';
        };

        outputs = mkOption {
        type = with types; attrsOf (attrsOf anything);
        default = {};
        description = ''
          Output configurations for DNS providers, file exports, and remote aggregation.

          DNS providers use type = "dns" with provider-specific settings.
          File outputs use type = "file" with format and path settings.
          Remote outputs use type = "remote" for aggregation servers.
        '';
        };

        domains = mkOption {
        type = with types; attrsOf (attrsOf anything);
        default = {};
        description = ''
          Domain configurations with input/output profile associations.
          Each domain specifies which input providers can create records
          and which output profiles should process those records.
        '';
        };

        api = mkOption {
        type = with types; attrsOf anything;
        default = {};
        description = ''
          API server configuration for receiving DNS records from remote herald instances.
        '';
        };

        include = lib.mkOption {
        type = with types; nullOr (either str (listOf str));
        default = null;
        description = ''
          One or more YAML files to include into the main configuration. Can be a string (single file) or a list of file paths.
          Included files are merged into the main config. Later files override earlier ones.
          Set to null to disable includes.
        '';
        };

        format = mkOption {
        type = with types; str;
        default = "yaml";
        description = ''
          File format for DNS records. Supported: "yaml", "json", "hosts", "zone".
        '';
        };
    };
    };

    config = mkIf cfg.enable {
      services.herald =
        let
        opt = name: val: def: lib.optionalAttrs (val != def) { "${name}" = val; };
        defaultPkg = inputs.herald.packages.${pkgs.system}.herald;

        includeFiles = let
          userIncludes = if cfg.include != null then (if builtins.isList cfg.include then cfg.include else [ cfg.include ]) else [];
          sopsIncludes = lib.optionals (builtins.pathExists "${config.host.configDir}/hosts/common/secrets/herald/shared.yml.enc")
          [ config.sops.secrets."herald/shared.yaml".path ]
          ++ lib.optionals (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/herald/herald.yml.enc")
          [ config.sops.secrets."herald/${config.host.network.hostname}.yaml".path ];
        in userIncludes ++ sopsIncludes;

        finalInclude = if includeFiles == [] then null else includeFiles;
        in
          lib.mkMerge [
            (opt "service.enable" cfg.service.enable true)
            (opt "package" cfg.package defaultPkg)
            (opt "configFile" cfg.configFile "herald.yml")
            (opt "general" cfg.general {})
            (opt "defaults" cfg.defaults {})
            (opt "inputs" cfg.inputs {})
            (opt "outputs" cfg.outputs {})
            (opt "domains" cfg.domains {})
            (opt "api" cfg.api {})
            (opt "include" finalInclude null)
            {
                enable = cfg.enable;
            }
          ];

    # Ensure herald starts after docker if docker is enabled
    systemd.services.herald = lib.mkIf config.host.feature.virtualization.docker.enable {
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
    };

    sops.secrets = {
      ## Only read these secrets if the secret exists
      "herald/${config.host.network.hostname}.yaml" = lib.mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/herald/herald.yml.enc")  {
        sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/herald/herald.yml.enc";
        format = "binary";
        key = "";
        restartUnits = [ "herald.service" ];
      };
      "herald/shared.yaml" = lib.mkIf (builtins.pathExists "${config.host.configDir}/hosts/common/secrets/herald/shared.yml.enc")  {
        sopsFile = "${config.host.configDir}/hosts/common/secrets/herald/shared.yml.enc";
        format = "binary";
        key = "";
        restartUnits = [ "herald.service" ];
      };
    };
  };
}
