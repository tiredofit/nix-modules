{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.host.feature.virtualization.docker;
  docker_storage_driver =
    if config.host.filesystem.btrfs.enable
    then "btrfs"
    else "overlay2";

in
{
  options = {
    host.feature.virtualization.docker = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables tools and daemon for containerization";
      };
      daemon = {
        experimental = mkOption {
          default = true;
          type = types.bool;
          description = "Enable Docker experimental features.";
        };
        extra = mkOption {
          default = {};
          type = types.attrs;
          description = "Extra options to merge into daemon.json (advanced passthrough).";
        };
        liveRestore = mkOption {
          default = true;
          type = types.bool;
          description = "Enable live-restore for Docker daemon.";
        };
        listen = {
          hosts = mkOption {
            default = null;
            type = types.nullOr (types.listOf types.str);
            description = "List of hosts for Docker daemon to listen on (null for unset).";
          };
        };
        networking = {
          bridge_loopback = mkOption {
            default = true;
            type = types.bool;
            description = "Allow for NAT Loopback from br-* interfaces to allow resolving host";
          };
          forward = mkOption {
            default = null;
            type = types.nullOr types.bool;
            description = "Enable or disable net.ipv4.ip_forward for Docker daemon (null for unset).";
          };
          iptables = mkOption {
            default = null;
            type = types.nullOr types.bool;
            description = "Enable or disable Docker's iptables management (null for unset).";
          };
          ipv6 = mkOption {
            default = null;
            type = types.nullOr types.bool;
            description = "Enable or disable IPv6 for Docker daemon (null for unset).";
          };
          masquerade = mkOption {
            default = null;
            type = types.nullOr types.bool;
            description = "Enable or disable IP masquerading for Docker daemon (null for unset).";
          };
          mtu = mkOption {
            default = null;
            type = types.nullOr types.int;
            description = "MTU for Docker bridge network (null for Docker default).";
          };
        };
        registry = {
          maxConcurrentDownloads = mkOption {
            default = null;
            type = types.nullOr types.int;
            description = "Max concurrent downloads for each pull (null for Docker default).";
          };
          maxConcurrentUploads = mkOption {
            default = null;
            type = types.nullOr types.int;
            description = "Max concurrent uploads for each push (null for Docker default).";
          };
          maxDownloadAttempts = mkOption {
            default = null;
            type = types.nullOr types.int;
            description = "Max download attempts for each pull (null for Docker default).";
          };
        };
        shutdownTimeout = mkOption {
          default = 120;
          type = types.int;
          description = "Shutdown timeout for Docker daemon (seconds).";
        };
        tls = {
          enable = mkOption {
            default = null;
            type = types.nullOr types.bool;
            description = "Enable or disable TLS for Docker daemon (null for unset).";
          };
          file = {
            ca = mkOption {
              default = null;
              type = types.nullOr types.path;
              description = "Path to CA certificate for Docker TLS (null for unset).";
            };
            cert = mkOption {
              default = null;
              type = types.nullOr types.path;
              description = "Path to server certificate for Docker TLS (null for unset).";
            };
            key = mkOption {
              default = null;
              type = types.nullOr types.path;
              description = "Path to server key for Docker TLS (null for unset).";
            };
          };
          verify = mkOption {
            default = null;
            type = types.nullOr types.bool;
            description = "Enable or disable TLS verification for Docker daemon (null for unset).";
          };
        };
        dns = {
          opts = mkOption {
            default = null;
            type = types.nullOr (types.listOf types.str);
            description = "List of DNS options for Docker daemon (null for unset).";
          };
          search = mkOption {
            default = null;
            type = types.nullOr (types.listOf types.str);
            description = "List of DNS search domains for Docker daemon (null for unset).";
          };
          serverIp = mkOption {
            default = null;
            type = types.nullOr (types.listOf types.str);
            description = "List of DNS servers for Docker daemon (null for unset).";
          };
        };
      };
      groupMembers = mkOption {
        default = [];
        type = types.listOf types.str;
        description = "Extra users to add to the docker group.";
      };
      networking = {
        bridge_loopback = mkOption {
          default = true;
          type = types.bool;
          description = "Allow for NAT Loopback from br-* interfaces to allow resolving host";
        };
      };
      networks = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            subnet = mkOption {
              type = types.str;
              description = "Subnet for the Docker network";
            };
            driver = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Docker network driver (default: bridge)";
            };
          };
        });
        default = {
          proxy = {
            subnet = "172.19.0.0/18";
            driver = "bridge";
          };
          proxy-internal = {
            subnet = "172.19.64.0/18";
            driver = "bridge";
          };
          services = {
            subnet = "172.19.128.0/18";
            driver = "bridge";
          };
          socket-proxy = {
            subnet = "172.19.192.0/18";
            driver = "bridge";
          };
        };
        description = "Custom Docker networks to create at activation time.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment = {
      etc = {
        "docker/daemon.json" = {
          text = builtins.toJSON (
            let
              base = {
                experimental = cfg.daemon.experimental;
                "live-restore" = cfg.daemon.liveRestore;
                "shutdown-timeout" = cfg.daemon.shutdownTimeout;
              } // (if cfg.daemon.registry.maxConcurrentDownloads != null then { "max-concurrent-downloads" = cfg.daemon.registry.maxConcurrentDownloads; } else {})
                // (if cfg.daemon.registry.maxConcurrentUploads != null then { "max-concurrent-uploads" = cfg.daemon.registry.maxConcurrentUploads; } else {})
                // (if cfg.daemon.registry.maxDownloadAttempts != null then { "max-download-attempts" = cfg.daemon.registry.maxDownloadAttempts; } else {})
                // (if cfg.daemon.networking.mtu != null then { mtu = cfg.daemon.networking.mtu; } else {})
                // (if cfg.daemon.networking.iptables != null then { iptables = cfg.daemon.networking.iptables; } else {})
                // (if cfg.daemon.networking.ipv6 != null then { ipv6 = cfg.daemon.networking.ipv6; } else {})
                // (if cfg.daemon.networking.forward != null then { "ip-forward" = cfg.daemon.networking.forward; } else {})
                // (if cfg.daemon.networking.masquerade != null then { "ip-masq" = cfg.daemon.networking.masquerade; } else {})
                // (if cfg.daemon.listen.hosts != null then { hosts = cfg.daemon.listen.hosts; } else {})
                // (if cfg.daemon.dns.serverIp != null then { dns = cfg.daemon.dns.serverIp; } else {})
                // (if cfg.daemon.dns.opts != null then { "dns-opts" = cfg.daemon.dns.opts; } else {})
                // (if cfg.daemon.dns.search != null then { "dns-search" = cfg.daemon.dns.search; } else {})
                // (if cfg.daemon.tls.enable != null then { tls = cfg.daemon.tls.enable; } else {})
                // (if cfg.daemon.tls.verify != null then { tlsverify = cfg.daemon.tls.verify; } else {})
                // (if cfg.daemon.tls.file.ca != null then { tlscacert = cfg.daemon.tls.file.ca; } else {})
                // (if cfg.daemon.tls.file.cert != null then { tlscert = cfg.daemon.tls.file.cert; } else {})
                // (if cfg.daemon.tls.file.key != null then { tlskey = cfg.daemon.tls.file.key; } else {})
                // cfg.daemon.extra;
            in base
          );
          mode = "0600";
        };
      };
    };

    host = {
      service = {
        docker_container_manager.enable = mkDefault true;
      };
    };

    networking.firewall.trustedInterfaces = mkIf (cfg.networking.bridge_loopback) [
      "br-+"
    ];

    programs = {
      bash = {
        interactiveShellInit = ''
          ### Docker
          if [ -n "$XDG_CONFIG_HOME" ] ; then
            export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
          else
            export DOCKER_CONFIG="$HOME/.config/docker"
          fi

          export docker_bin_location="$(which docker)"
          export DOCKER_TIMEOUT=${toString cfg.daemon.shutdownTimeout}

          # Figure out if we need to use sudo for docker commands
          if id -nG "$USER" | grep -qw "docker" || [ $(id -u) = "0" ]; then
            dsudo=""
          else
            dsudo='sudo'
          fi

          alias dex="$dsudo $docker_bin_location exec -it"                                                           # Execute interactive container, e.g., $dex base /bin/bash
          alias di="$dsudo $docker_bin_location images"                                                              # Get images
          alias dki="$dsudo $docker_bin_location run -it -P"                                                         # Run interactive container, e.g., $dki base /bin/bash
          alias dpsa="$dsudo docker_ps -a"                                                                           # Get process included stop container
          db() { $dsudo $docker_bin_location build -t="$1" .; }                                                      # Build Docker Image from Current Directory
          dri() { $dsudo $docker_bin_location rmi -f $($dsudo $docker_bin_location images -q); }                     # Forcefully Remove all images
          drm() { $dsudo $docker_bin_location rm $($dsudo $docker_bin_location ps -a -q); }                          # Remove all containers
          drmf() { $dsudo $docker_bin_location stop $($dsudo $docker_bin_location ps -a -q) -timeout $DOCKER_COMPOSE_TIMEOUT && $dsudo $docker_bin_location rm $($dsudo $docker_bin_location ps -a -q) ; } # Stop and remove all containers
          dstop() { $dsudo $docker_bin_location stop $($dsudo $docker_bin_location ps -a -q) -t $DOCKER_TIMEOUT; }   # Stop all containers

          # Get RAM Usage of a Container
          docker_mem() {
              if [ -f /sys/fs/cgroup/memory/docker/"$1"/memory.usage_in_bytes ]; then
                  echo $(($(cat /sys/fs/cgroup/memory/docker/"$1"/memory.usage_in_bytes) / 1024 / 1024)) 'MB'
              else
                  echo 'n/a'
              fi
          }
          alias dmem='docker_mem'

          # Get IP Address of a Container
          docker_ip() {
              ip=$($dsudo $docker_bin_location inspect --format="{{.NetworkSettings.IPAddress}}" "$1" 2>/dev/null)
              if (($? >= 1)); then
                  # Container doesn't exist
                  ip='n/a'
              fi
              echo $ip
          }
          alias dip='docker_ip'

          alias dps='$dsudo $docker_bin_location ps --format "table {{.ID}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}"'

          #  List the volumes for a given container
          docker_vol() {
            vols=$($dsudo $docker_bin_location inspect --format="{{.HostConfig.Binds}}" "$1")
            vols=''${vols:1:-1}
            for vol in $vols; do
              echo "$vol"
            done
          }
          alias dvol='docker_vol'

          if command -v "fzf" &>/dev/null; then
            # bash into running container
            alias dbash='c_name=$($dsudo $docker_bin_location ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed "/NAMES/d" | sort | fzf --tac |  ${pkgs.gawk}/bin/awk '"'"'{print $1;}'"'"') ; echo -e "\e[41m**\e[0m Entering $c_name from $(cat /etc/hostname)" ; $dsudo $docker_bin_location exec -e COLUMNS=$( tput cols ) -e LINES=$( tput lines ) -it $c_name bash'

            # view logs
            alias dlog='c_name=$($dsudo $docker_bin_location ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed "/NAMES/d" | sort | fzf --tac |  ${pkgs.gnused}/bin/awk '"'"'{print $1;}'"'"') ; echo -e "\e[41m**\e[0m Viewing $c_name from $(cat /etc/hostname)" ; $dsudo $docker_bin_location logs $c_name $1'

            # sh into running container
            alias dsh='c_name=$($dsudo $docker_bin_location ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed "/NAMES/d" | sort | fzf --tac |  ${pkgs.gnused}/bin/awk '"'"'{print $1;}'"'"') ; echo -e "\e[41m**\e[0m Entering $c_name from $(cat /etc/hostname)" ; $dsudo $docker_bin_location exec -e COLUMNS=$( tput cols ) -e LINES=$( tput lines ) -it $c_name sh'

            # Remove running container
            alias drm='$dsudo $docker_bin_location rm $( $dsudo $docker_bin_location ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed "/NAMES/d" | sort | fzf --tac |  ${pkgs.gawk}/bin/awk '"'"'{print $1;}'"'"' )'
          fi

          alias dpull='$dsudo $docker_bin_location pull'                                                                                                                                                                 # $docker_bin_location Pull
        '';
      };
    };

    system.activationScripts.create_docker_networks =
      let
        networks = config.host.feature.virtualization.docker.networks;
        mkCreate = name: net: ''
          ${config.virtualisation.docker.package}/bin/docker network inspect ${name} > /dev/null || \
            ${config.virtualisation.docker.package}/bin/docker network create ${name} --subnet ${net.subnet}${if net.driver != null then " --driver ${net.driver}" else ""}
        '';
      in
        concatStringsSep "\n" (mapAttrsToList mkCreate networks);

    users.groups.docker = {
      members = mkDefault cfg.groupMembers;
    };

    virtualisation = {
      docker = {
        enable = mkDefault true;
        enableOnBoot = mkDefault false;
        logDriver = mkDefault "local";
        storageDriver = docker_storage_driver;
      };
      oci-containers.backend = mkDefault "docker";
    };
  };
}
