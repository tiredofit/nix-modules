{ config, inputs, lib, pkgs, ... }:
  let
    cfg = config.host.service.container-dns-companion;
  in
    with lib;
    {
      imports = [
        inputs.container-dns-companion.nixosModules.default
      ];

      options = {
        host.service.container-dns-companion = {
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
            default = inputs.container-dns-companion.packages.${pkgs.system}.container-dns-companion;
            description = "Container DNS Companion package to use.";
          };

          configFile = mkOption {
            type = with types; str;
            default = "container-dns-companion.yml";
            description = "File name under /etc to the YAML configuration file for Container DNS Companion.";
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
            description = "Poll profiles for service/container discovery.";
          };

          domains = mkOption {
            type = with types; attrsOf (attrsOf anything);
            default = {};
            description = "Domain profiles.";
          };

          include = lib.mkOption {
            type = with types; either str (listOf str);
            default = [
              config.sops.secrets."cdc/shared.yaml".path
              config.sops.secrets."cdc/${config.host.network.hostname}.yaml".path
            ];
            example = [ "/etc/container-dns-companion/extra1.yml" "/etc/container-dns-companion/extra2.yml" ];
            description = ''
              One or more YAML files to include into the main configuration. Can be a string (single file) or a list of file paths.
            '';
          };
        };
      };

      config = mkIf cfg.enable {
        services.container-dns-companion =
          let
            opt = name: val: def: lib.optionalAttrs (val != def) { "${name}" = val; };
            defaultPkg = inputs.container-dns-companion.packages.${pkgs.system}.container-dns-companion;
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
            (opt "include" cfg.include null)
            {
              enable = cfg.enable;
            }
          ];

    sops.secrets = {
      ## Only read these secrets if the secret exists
      "cdc/${config.host.network.hostname}.yaml" = lib.mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/cdc/cdc.yml.enc")  {
        sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/cdc/cdc.yml.enc";
        format = "binary";
        key = "";
        restartUnits = [ "container-dns-companion.service" ];
      };
      "cdc/shared.yaml" = lib.mkIf (builtins.pathExists "${config.host.configDir}/hosts/common/secrets/cdc/shared.yml.enc")  {
        sopsFile = "${config.host.configDir}/hosts/common/secrets/cdc/shared.yml.enc";
        format = "binary";
        key = "";
        restartUnits = [ "container-dns-companion.service" ];
      };
    };
  };
}
