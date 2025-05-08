{config, inputs, lib, pkgs, ...}:

let
  cfg = config.host.service.zt-dns-companion;
in
  with lib;
{
  imports = [
    inputs.zt-dns-companion.nixosModules.default
  ];

  options = {
    host.service.zt-dns-companion = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable the ZeroTier DNS Companion service to manage DNS for ZeroTier networks.";
      };

      service = {
        enable = mkOption {
          default = true;
          type = with types; bool;
          description = "Auto start on server start";
        };

        timerInterval = mkOption {
          type = with types; str;
          default = "1m";
          description = "Interval for the systemd timer (e.g., 1m, 5m, 1h).";
        };
      };

      package = mkOption {
        type = with types; package;
        default = inputs.zt-dns-companion.packages.${pkgs.system}.zt-dns-companion;
        description = "ZeroTier DNS Companion package to use.";
      };

      configFile = mkOption {
        type = with types; str;
        default = "/etc/zt-dns-companion.conf";
        description = "Path to the configuration file for ZT DNS Companion.";
      };

      profiles = mkOption {
        type = with types; attrsOf (attrsOf anything);
        default = {};
        example = {
          example1 = {
            filterType = "interface";
            filterInclude = [ "zt12345678" "zt87654321" ];
            autoRestart = false;
          };
          example2 = {
            filterType = "network";
            filterInclude = [ "ztnetwork1" "ztnetwork2" ];
            mode = "resolved";
            dnsOverTLS = true;
          };
        };
        description = ''
          Additional profiles for the zt-dns-companion configuration.
          Each profile is an attribute set where the key is the profile name
          and the value is an attribute set of options for that profile.

          Profiles inherit values from the default profile unless explicitly overridden.

          Filtering options:
          - filterType: Type of filter ("interface", "network", "network_id", or "none")
          - filterInclude: List of items to include based on filter type (empty or "any"/"all"/"ignore" means include all)
          - filterExclude: List of items to exclude based on filter type (empty or "none"/"ignore" means exclude nothing)
        '';
      };

      profile = mkOption {
        type = with types; str;
        default = "";
        description = ''
          The profile to load for the zt-dns-companion service. This should match one of the keys in the `profiles` option.
          If not specified, the default profile will be used.
        '';
      };

      mode = mkOption {
        type = with types; enum [ "auto" "networkd" "resolved" ];
        default = "auto";
        description = "Mode of operation (autodetected, networkd or resolved).";
      };

      host = mkOption {
        type = with types; str;
        default = "http://localhost";
        description = "ZeroTier client host address.";
      };

      port = mkOption {
        type = with types; int;
        default = config.host.network.vpn.zerotier.port;
        description = "ZeroTier client port number.";
      };

      logLevel = mkOption {
        type = with types; enum [ "debug" "info" ];
        default = "info";
        description = "Set the logging level (info or debug).";
      };

      tokenFile = mkOption {
        type = with types; str;
        default = "/var/lib/zerotier-one/authtoken.secret";
        description = "Path to the ZeroTier authentication token file.";
      };

      filterType = mkOption {
        type = with types; enum [ "interface" "network" "network_id" "none" ];
        default = "none";
        description = "Type of filter to apply (interface, network, network_id, or none).";
      };

      filterInclude = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          List of items to include based on filter-type.
          Empty list or values like "any", "all", or "ignore" mean include all.
        '';
      };

      filterExclude = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          List of items to exclude based on filter-type.
          Empty list or values like "none", or "ignore" mean exclude nothing.
        '';
      };

      addReverseDomains = mkOption {
        type = with types; bool;
        default = false;
        description = "Add ip6.arpa and in-addr.arpa search domains.";
      };

      autoRestart = mkOption {
        type = with types; bool;
        default = true;
        description = "Automatically restart systemd-networkd when things change.";
      };

      dnsOverTLS = mkOption {
        type = with types; bool;
        default = false;
        description = "Automatically prefer DNS-over-TLS. Requires ZeroNSd v0.4 or better.";
      };

      multicastDNS = mkOption {
        type = with types; bool;
        default = false;
        description = "Enable mDNS resolution on the zerotier interface.";
      };

      reconcile = mkOption {
        type = with types; bool;
        default = true;
        description = "Automatically remove left networks from systemd-networkd configuration.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.host.network.vpn.zerotier.enable;
        message = "The zt-dns-companion service can only be used if host.network.vpn.zerotier is enabled.";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    services.zt-dns-companion = mkMerge [
      {
        enable = true;
        service = {
          enable = cfg.service.enable;
          timerInterval = cfg.service.timerInterval;
        };
      }

      (mkIf (cfg.package != inputs.zt-dns-companion.packages.${pkgs.system}.zt-dns-companion) {
        package = cfg.package;
      })
      (mkIf (cfg.configFile != "/etc/zt-dns-companion.conf") {
        configFile = cfg.configFile;
      })
      (mkIf (cfg.profile != "") {
        profile = cfg.profile;
      })
      (mkIf (cfg.mode != "auto") {
        mode = cfg.mode;
      })
      (mkIf (cfg.host != "http://localhost") {
        host = cfg.host;
      })
      (mkIf (cfg.port != 9993) {
        port = cfg.port;
      })
      (mkIf (cfg.logLevel != "info") {
        logLevel = cfg.logLevel;
      })
      (mkIf (cfg.tokenFile != "/var/lib/zerotier-one/authtoken.secret") {
        tokenFile = cfg.tokenFile;
      })
      (mkIf (cfg.filterType != "none") {
        filterType = cfg.filterType;
      })
      (mkIf (cfg.filterInclude != []) {
        filterInclude = cfg.filterInclude;
      })
      (mkIf (cfg.filterExclude != []) {
        filterExclude = cfg.filterExclude;
      })
      (mkIf (cfg.addReverseDomains != false) {
        addReverseDomains = cfg.addReverseDomains;
      })
      (mkIf (cfg.autoRestart != true) {
        autoRestart = cfg.autoRestart;
      })
      (mkIf (cfg.dnsOverTLS != false) {
        dnsOverTLS = cfg.dnsOverTLS;
      })
      (mkIf (cfg.multicastDNS != false) {
        multicastDNS = cfg.multicastDNS;
      })
      (mkIf (cfg.reconcile != true) {
        reconcile = cfg.reconcile;
      })
      (mkIf (cfg.profiles != {}) {
        profiles = cfg.profiles;
      })
    ];
  };
}
