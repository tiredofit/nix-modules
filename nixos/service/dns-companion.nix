{ config, inputs, lib, pkgs, ... }:
  let
    cfg = config.host.service.dns-companion;
  in
    with lib;
    {
      imports = [
        inputs.dns-companion.nixosModules.default
      ];

      options = {
        host.service.dns-companion = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Manage DNS records based on DNS servers based on events from Docker or Traefik.";
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
            default = inputs.dns-companion.packages.${pkgs.system}.dns-companion;
            description = "DNS Companion package to use.";
          };

          configFile = mkOption {
            type = with types; str;
            default = "dns-companion.yml";
            description = "File name under /etc to the YAML configuration file for DNS Companion.";
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

          providers = mkOption {
            type = with types; attrsOf (attrsOf anything);
            default = {};
            description = "DNS provider profiles.";
          };

          polls = mkOption {
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
                source = "/var/lib/dns-companion/records.yaml";
                format = "yaml";
                interval = "-1";
                record_remove_on_stop = true;
                process_existing = true;
              };
              remote = {
                type = "remote";
                remote_url = "https://example.com/records.yaml";
                format = "yaml";
                interval = "30s";
                process_existing = true;
                record_remove_on_stop = true;
                remote_auth_user = "myuser";
                remote_auth_pass = "mypassword";
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
                filter_type = "online";
                filter_value = "true";
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
                filter_type = "online";
                filter_value = "true";
              };
            };
            description = ''
              Poll profiles for service/container discovery. Each key is the poller name, and the value is an attribute set of options for that poller
            '';
          };

          domains = mkOption {
            type = with types; attrsOf (attrsOf anything);
            default = {};
            example = {
              example_com = {
                name = "example.com";
                provider = "cloudflare";
                zone_id = "your_zone_id_here";
                record = {
                  type = "A";
                  ttl = 60;
                  target = "192.0.2.1";
                  update_existing = true;
                  allow_multiple = true;
                };
                include_subdomains = [ ];
                exclude_subdomains = [ "dev" "staging" ];
              };
            };
            description = ''
              Domain profiles. Each key is the domain profile name, and the value is an attribute set of options for that domain.
            '';
          };

          outputs = mkOption {
            type = with types; attrsOf (attrsOf anything);
            default = {};
            example = {
              hosts_export = {
                format = "hosts";
                path = "/etc/hosts.dns-companion";
                domains = [ "all" ];
                user = "root";
                group = "root";
                mode = 420; # 0644
                enable_ipv4 = true;
                enable_ipv6 = false;
                header_comment = "Managed by DNS Companion";
              };
              json_export = {
                format = "json";
                path = "/var/lib/dns-companion/records.json";
                domains = [ "example.com" "test.com" ];
                user = "dns-companion";
                group = "dns-companion";
                mode = 420;
                generator = "dns-companion-nixos";
                hostname = "nixos-server";
                comment = "Exported DNS records";
                indent = true;
              };
              send_to_api = {
                format = "remote";
                url = "https://dns-master.company.com/api/dns";
                client_id = "server1";
                token = "your_bearer_token_here";
                timeout = "30s";
                data_format = "json";
                log_level = "info";
                tls = {
                  verify = true;
                  ca = "/etc/ssl/ca/server-ca.pem";
                  cert = "/etc/ssl/certs/client.pem";
                  key = "/etc/ssl/private/client.key";
                };
              };
            };
            description = ''
              Output profile system. Configure multiple independent output profiles
              that can target specific domains, multiple domains, or all domains ("all").

              Each profile supports format-specific options like SOA records for zone files,
              metadata for YAML/JSON exports, and file ownership settings.

              The remote format allows pushing DNS records to a central aggregation server.
            '';
          };

          api = mkOption {
            type = with types; attrsOf anything;
            default = {};
            example = {
              enabled = true;
              port = "8080";
              listen = [ "all" "!docker*" "!lo" ];
              endpoint = "/api/dns";
              client_expiry = "10m";
              log_level = "info";
              profiles = {
                server1 = {
                  token = "your_bearer_token_here";
                  output_profile = "aggregated_zones";
                };
                server2 = {
                  token = "file:///var/run/secrets/server2_token";
                  output_profile = "special_zones";
                };
              };
              tls = {
                cert = "/etc/ssl/certs/dns-companion.crt";
                key = "/etc/ssl/private/dns-companion.key";
                ca = "/etc/ssl/ca/client-ca.pem";
              };
            };
            description = ''
              API server configuration for receiving DNS records from remote dns-companion instances.

              Features:
              - Bearer token authentication per client
              - Failed attempt tracking and rate limiting
              - TLS with optional mutual authentication
              - Comprehensive security logging
              - Automatic client expiry and cleanup
              - Route client data to different output profiles
            '';
          };

          include = lib.mkOption {
            type = with types; nullOr (either str (listOf str));
            default = null;
            example = [ "/etc/dns-companion/extra1.yml" "/etc/dns-companion/extra2.yml" ];
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
        services.dns-companion =
          let
            opt = name: val: def: lib.optionalAttrs (val != def) { "${name}" = val; };
            defaultPkg = inputs.dns-companion.packages.${pkgs.system}.dns-companion;

            # Build include list from user config and existing SOPS secrets
            includeFiles = let
              userIncludes = if cfg.include != null then (if builtins.isList cfg.include then cfg.include else [ cfg.include ]) else [];
              sopsIncludes = lib.optionals (builtins.pathExists "${config.host.configDir}/hosts/common/secrets/dns-companion/shared.yml.enc")
                [ config.sops.secrets."dns-companion/shared.yaml".path ]
                ++ lib.optionals (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/dns-companion/dns-companion.yml.enc")
                [ config.sops.secrets."dns-companion/${config.host.network.hostname}.yaml".path ];
            in userIncludes ++ sopsIncludes;

            finalInclude = if includeFiles == [] then null else includeFiles;
          in
          lib.mkMerge [
            (opt "service.enable" cfg.service.enable true)
            (opt "package" cfg.package defaultPkg)
            (opt "configFile" cfg.configFile null)
            (opt "defaults" cfg.defaults {})
            (opt "general" cfg.general {})
            (opt "providers" cfg.providers {})
            (opt "polls" cfg.polls {})
            (opt "domains" cfg.domains {})
            (opt "outputs" cfg.outputs {})
            (opt "api" cfg.api {})
            (opt "include" finalInclude null)
            {
              enable = cfg.enable;
            }
          ];

      sops.secrets = {
        ## Only read these secrets if the secret exists
        "dns-companion/${config.host.network.hostname}.yaml" = lib.mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/dns-companion/dns-companion.yml.enc")  {
          sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/dns-companion/dns-companion.yml.enc";
          format = "binary";
          key = "";
          restartUnits = [ "dns-companion.service" ];
        };
        "dns-companion/shared.yaml" = lib.mkIf (builtins.pathExists "${config.host.configDir}/hosts/common/secrets/dns-companion/shared.yml.enc")  {
          sopsFile = "${config.host.configDir}/hosts/common/secrets/dns-companion/shared.yml.enc";
          format = "binary";
          key = "";
          restartUnits = [ "dns-companion.service" ];
        };
      };
    };
}
