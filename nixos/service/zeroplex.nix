{config, inputs, lib, pkgs, ...}:

let
  cfg = config.host.service.zeroplex;
in
  with lib;
{
  imports = [
    inputs.zeroplex.nixosModules.default
  ];

  options = {
    host.service.zeroplex = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable the ZeroPlex service to manage DNS for ZeroTier networks.";
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
        default = inputs.zeroplex.packages.${pkgs.system}.zeroplex;
        description = "ZeroPlex package to use.";
      };

      configFile = mkOption {
        type = with types; str;
        default = "/etc/zeroplex.yml";
        description = "Path to the YAML configuration file for ZeroPlex.";
      };

      mode = mkOption {
        type = with types; enum [ "auto" "networkd" "resolved" ];
        default = "auto";
        description = "Mode of operation (autodetected, networkd or resolved).";
      };
      log = mkOption {
        type = types.submodule {
          options = {
            level = mkOption {
              type = types.enum [ "error" "warn" "info" "verbose" "debug" "trace" ];
              default = "verbose";
              description = "Set the logging level (error, warn, info, verbose, debug, or trace).";
            };
            type = mkOption {
              type = types.str;
              default = "console";
              description = "Set the logging type (console, file, or both).";
            };
            file = mkOption {
              type = types.str;
              default = "/var/log/zeroplex.log";
              description = "Set the log file path (used if log type is file or both).";
            };
            timestamps = mkOption {
              type = types.bool;
              default = false;
              description = "Log timestamps (YYYY-MM-DD HH:MM:SS).";
            };
          };
        };
        default = {
          level = "verbose";
          type = "console";
          file = "/var/log/zeroplex.log";
          timestamps = false;
        };
        description = "Logging configuration (level, type, file, timestamps).";
      };
      daemon = mkOption {
        type = types.submodule {
          options = {
            enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Default to daemon mode.";
            };
            poll_interval = mkOption {
              type = types.str;
              default = "1m";
              description = "Polling interval.";
            };
          };
        };
        default = {
          enabled = true;
          poll_interval = "15m";
        };
        description = "Daemon configuration.";
      };
      client = mkOption {
        type = types.submodule {
          options = {
            host = mkOption {
              type = types.str;
              default = "http://localhost";
              description = "ZeroTier client host address.";
            };
            port = mkOption {
              type = types.int;
              default = 9993;
              description = "ZeroTier client port number.";
            };
            token_file = mkOption {
              type = types.str;
              default = "/var/lib/zerotier-one/authtoken.secret";
              description = "Path to the ZeroTier authentication token file.";
            };
          };
        };
        default = {
          host = "http://localhost";
          port = 9993;
          token_file = "/var/lib/zerotier-one/authtoken.secret";
        };
        description = "Client configuration.";
      };
      features = mkOption {
        type = types.submodule {
          options = {
            dns_over_tls = mkOption {
              type = types.bool;
              default = false;
              description = "Prefer DNS-over-TLS.";
            };
            add_reverse_domains = mkOption {
              type = types.bool;
              default = false;
              description = "Add ip6.arpa and in-addr.arpa search domains.";
            };
            multicast_dns = mkOption {
              type = types.bool;
              default = true;
              description = "Enable mDNS resolution on the ZeroTier interface.";
            };
            restore_on_exit = mkOption {
              type = types.bool;
              default = true;
              description = "Restore original DNS settings for all managed interfaces on exit.";
            };
            watchdog_ip = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "IP address to ping for DNS watchdog (default: first DNS server from ZeroTier config).";
            };
            watchdog_hostname = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "DNS hostname to resolve for DNS watchdog (optional, enables hostname mode).";
            };
            watchdog_expected_ip = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Expected IP address for resolved hostname (optional, for split-horizon/hijack detection).";
            };
            watchdog_interval = mkOption {
              type = types.str;
              default = "1m";
              description = "Interval for DNS watchdog ping (e.g., 1m).";
            };
            watchdog_backoff = mkOption {
              type = types.listOf types.str;
              default = [ "10s" "20s" "30s" ];
              description = "Backoff intervals after failed ping (e.g., [10s 20s 30s]).";
            };
          };
        };
        default = {
          dns_over_tls = false;
          add_reverse_domains = false;
          multicast_dns = false;
          restore_on_exit = false;
          watchdog_ip = null;
          watchdog_hostname = null;
          watchdog_expected_ip = null;
          watchdog_interval = "1m";
          watchdog_backoff = [ "10s" "20s" "30s" ];
        };
        description = "Feature toggles.";
      };
      interface_watch = mkOption {
        type = types.submodule {
          options = {
            mode = mkOption {
              type = types.str;
              default = "event";
              description = "Interface watch mode (event, poll, off).";
            };
            retry = mkOption {
              type = types.submodule {
                options = {
                  count = mkOption {
                    type = types.int;
                    default = 10;
                    description = "Number of retries after interface event.";
                  };
                  delay = mkOption {
                    type = types.str;
                    default = "10s";
                    description = "Delay between retries (duration string).";
                  };
                };
              };
              default = {
                count = 10;
                delay = "10s";
              };
              description = "Retry configuration.";
            };
          };
        };
        default = {
          mode = "event";
          retry = {
            count = 10;
            delay = "10s";
          };
        };
        description = "Interface watch configuration.";
      };
      networkd = mkOption {
        type = types.submodule {
          options = {
            auto_restart = mkOption {
              type = types.bool;
              default = true;
              description = "Automatically restart systemd-networkd when things change.";
            };
            reconcile = mkOption {
              type = types.bool;
              default = true;
              description = "Automatically remove left networks from systemd-networkd configuration.";
            };
          };
        };
        default = {
          auto_restart = true;
          reconcile = true;
        };
        description = "Networkd configuration.";
      };
      profiles = mkOption {
        type = with types; attrsOf (attrsOf anything);
        default = {};
        description = "Additional profiles for the zeroplex configuration using advanced filtering. Each profile is an attribute set where the key is the profile name and the value is a nested attribute set of options for that profile.";
      };
      profile = mkOption {
        type = types.str;
        default = "";
        description = "The profile to load for the zeroplex service. This should match one of the keys in the `profiles` option. If not specified, the default profile will be used.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.zeroplex = lib.mkMerge [
      { enable = true; }
      (lib.optionalAttrs (cfg.service.enable != null) { service.enable = cfg.service.enable; })
      (lib.optionalAttrs (cfg.package != null) { package = cfg.package; })
      (lib.optionalAttrs (cfg.configFile != null) { configFile = cfg.configFile; })
      (lib.optionalAttrs (cfg.profiles != {}) { profiles = cfg.profiles; })
      (lib.optionalAttrs (cfg.profile != "") { profile = cfg.profile; })
      (lib.optionalAttrs (cfg.mode != null) { mode = cfg.mode; })
      (lib.optionalAttrs (cfg.log != null) { log = cfg.log; })
      (lib.optionalAttrs (cfg.daemon != null) { daemon = cfg.daemon; })
      (lib.optionalAttrs (cfg.client != null) { client = cfg.client; })
      (lib.optionalAttrs (cfg.features != null) { features = cfg.features; })
      (lib.optionalAttrs (cfg.interface_watch != null) { interface_watch = cfg.interface_watch; })
      (lib.optionalAttrs (cfg.networkd != null) { networkd = cfg.networkd; })
    ];
  };
}
