{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.virtualization.docker.container_manager;
  service = config.host.service.docker_container_manager;
in
  with lib;
{
  options = {
    host = {
      feature.virtualization.docker.container_manager = {
        enable = mkOption {
          default = (config.host.feature.virtualization.docker.enable) && (config.host.feature.virtualization.docker.compose.enable);
          type = with types; bool;
          description = "Enables docker compose utility and associated aliases";
        };
      };
      service.docker_container_manager = {
        enable = mkOption {
          default = false;
          type = with types; bool;
          description = "Start and stop containers on bootup / shutdown";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "container-tool" ''
        set -euo pipefail

        export DOCKER_COMPOSE_TIMEOUT=${toString config.host.feature.virtualization.docker.daemon.shutdownTimeout}
        if ! [[ "$DOCKER_COMPOSE_TIMEOUT" =~ ^[0-9]+$ ]]; then
          export DOCKER_COMPOSE_TIMEOUT="''${DOCKER_TIMEOUT:-120}"
        fi

        if command -v awk >/dev/null 2>&1; then
          awk_bin="$(command -v awk)"
        elif [ -x "${pkgs.gawk}/bin/awk" ]; then
          awk_bin="$${pkgs.gawk}/bin/awk"
        else
          echo "Error: 'awk' command not found. Please install 'awk'." >&2
          exit 1
        fi

        if command -v docker >/dev/null 2>&1; then
          docker_bin="$(command -v docker)"
        elif [ -x "${config.virtualisation.docker.package}/bin/docker" ]; then
          docker_bin="${config.virtualisation.docker.package}/bin/docker"
        else
          echo "Error: docker binary not found in PATH." >&2
          exit 1
        fi

        if command -v docker-compose >/dev/null 2>&1; then
          docker_compose_bin="$(command -v docker-compose)"
        elif [ -x "${pkgs.docker-compose}/bin/docker-compose" ]; then
          docker_compose_bin="${pkgs.docker-compose}/bin/docker-compose"
        else
          echo "Error: docker-compose binary not found in PATH." >&2
          exit 1
        fi

        if command -v grep >/dev/null 2>&1; then
          grep_bin="$(command -v grep)"
        elif [ -x "${pkgs.gnugrep}/bin/grep" ]; then
          grep_bin="${pkgs.gnugrep}/bin/grep"
        else
          echo "Error: 'grep' command not found. Please install 'grep'." >&2
          exit 1
        fi

        if command -v tail >/dev/null 2>&1; then
          tail_bin="$(command -v tail)"
        elif [ -x "${pkgs.coreutils}/bin/tail" ]; then
          tail_bin="${pkgs.coreutils}/bin/tail"
        else
          echo "Error: 'tail' command not found. Please install 'tail'." >&2
          exit 1
        fi

        if id -nG "$USER" | $grep_bin -qw "docker" || [ $(id -u) = "0" ]; then
          dsudo=""
        else
          dsudo='sudo'
        fi

        DOCKER_COMPOSE_STACK_DATA_PATH=''${DOCKER_COMPOSE_STACK_DATA_PATH:-"/var/local/data/"}
        DOCKER_STACK_SYSTEM_DATA_PATH=''${DOCKER_STACK_SYSTEM_DATA_PATH:-"/var/local/data/_system/"}
        DOCKER_COMPOSE_STACK_APP_RESTART_FIRST=''${DOCKER_COMPOSE_STACK_APP_RESTART_FIRST:-"auth.example.com"}
        DOCKER_STACK_SYSTEM_APP_RESTART_ORDER=''${DOCKER_STACK_SYSTEM_APP_RESTART_ORDER:-"socket-proxy coredns error-pages traefik traefik-internal unbound openldap postfix-relay llng-handler restic clamav zabbix zabbix-proxy"}

        ###
        #  system directory: $DOCKER_STACK_SYSTEM_DATA_PATH
        #  application directory: $DOCKER_COMPOSE_STACK_DATA_PATH
        #  order to start containers:
        #  1. if $DOCKER_COMPOSE_STACK_APP_RESTART_FIRST (under $DOCKER_COMPOSE_STACK_DATA_PATH), restart first
        #  2. restart containers under system directory in the order of:
        #     \DOCKER_STACK_SYSTEM_APP_RESTART_ORDER
        #  3. restart containers under application directory (no particular order)
        #
        #  Usage:
        #  container-tool core
        #  container-tool applications
        #  container-tool (default - all)
        #  container-tool stop
        ###

        ct_pull_images () {
          for stack_dir in "$@" ; do
            if [ ! -f "$stack_dir"/.norestart ]; then
              echo "**** [container-tool] [pull] Pulling Images - $stack_dir"
              $docker_compose_bin -f "$stack_dir"/*compose.yml pull
            else
              echo "**** [container-tool] [pull] Skipping - $stack_dir"
            fi
          done
        }

        ct_pull_restart () {
          for stack_dir in "$@" ; do
            if [ ! -f "$stack_dir"/.norestart ]; then
              echo "**** [container-tool] [pull_restart] Pulling Images - $stack_dir"
              $docker_compose_bin -f "$stack_dir"/*compose.yml pull
              echo "**** [container-tool] [pull_restart] Bringing up stack - $stack_dir"
              $docker_compose_bin -f "$stack_dir"/*compose.yml up -d
            else
              echo "**** [container-tool] [pull_restart] Skipping - $stack_dir"
            fi
          done
        }

        ct_restart () {
          for stack_dir in "$@" ; do
            if [ ! -f "$stack_dir"/.norestart ]; then
              echo "**** [container-tool] [restart] Bringing down stack - $stack_dir"
              $docker_compose_bin -f "$stack_dir"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
              echo "**** [container-tool] [restart] Bringing up stack - $stack_dir"
              $docker_compose_bin -f "$stack_dir"/*compose.yml up -d
            else
              echo "**** [container-tool] [restart] Skipping - $stack_dir"
            fi
          done
        }

        ct_restart_service () {
          for stack_dir in "$@" ; do
            if [ ! -f "$stack_dir"/.norestart ]; then
              if $dsudo systemctl list-unit-files docker-"$stack_dir".service &>/dev/null ; then
                echo "**** [container-tool] [restart] Bringing down stack - $stack_dir"
                $dsudo systemctl stop docker-"$stack_dir".service
                echo "**** [container-tool] [restart] Bringing up stack - $stack_dir"
                $dsudo systemctl start docker-"$stack_dir".service
              else
                :
                #echo "**** [container-tool] [restart] Skipping - $stack_dir (no systemd service found)"
              fi
            else
              echo "**** [container-tool] [restart] Skipping $stack_dir due to .norestart file"
            fi
          done
        }

        ct_stop () {
          for stack_dir in "$@" ; do
            echo "**** [container-tool] [stop] Stopping stack - $stack_dir"
            $docker_compose_bin -f "$stack_dir"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
          done
        }

        ct_stop_service() {
          for stack_dir in "$@" ; do
            if $dsudo systemctl list-unit-files docker-"$stack_dir".service &>/dev/null ; then
              echo "**** [container-tool] [stop_service] Stopping stack - $stack_dir"
              $dsudo systemctl stop docker-"$stack_dir".service
            fi
          done
        }

        ct_sort_order () {
          local -n tmparr=$1
          local sorted=()
          for predef in "''${predef_order[@]}"; do
            for item in "''${tmparr[@]}"; do
              if [ "$(basename "$item" | xargs)" = "$(echo "$predef" | xargs)" ]; then
                sorted+=("$item")
                break
              fi
            done
          done
          tmparr=("''${sorted[@]}")
        }

        ct_restart_sys_containers () {
          predef_order=($(echo "$DOCKER_STACK_SYSTEM_APP_RESTART_ORDER"))
          curr_order=()
          for stack_dir in "$DOCKER_STACK_SYSTEM_DATA_PATH"/* ; do
            curr_order=("''${curr_order[@]}" "''${stack_dir##*/}")
          done
          ct_sort_order curr_order
          ct_restart_service "''${curr_order[@]}"
        }

        ct_stop_stack () {
          stacks=$($docker_compose_bin ls | $tail_bin -n +2 | $awk_bin '{print $1}')
          for stack in $stacks; do
            stack_image=$($docker_compose_bin -p $stack images | $tail_bin -n +2 |  $awk_bin '{print $1,$2}' | $grep_bin "db-backup")
            if [ "''${1:-}" != "nobackup" ] ; then
              if [[ $stack_image =~ .*"db-backup".* ]] ; then
                stack_container_name=$(echo "$stack_image" | $awk_bin '{print $1}')
                echo "** Backing up database for '$stack_container_name' before stopping"
                $docker_bin exec $stack_container_name /usr/local/bin/backup-now
              fi
            fi
            echo "** Gracefully stopping compose stack: $stack"
            $docker_compose_bin -p $stack down --timeout $DOCKER_COMPOSE_TIMEOUT
          done
        }

        ct_stop_sys_containers () {
          predef_order=($(echo "$DOCKER_STACK_SYSTEM_APP_RESTART_ORDER"))
          curr_order=()
          for stack_dir in "$DOCKER_STACK_SYSTEM_DATA_PATH"/* ; do
            curr_order=("''${curr_order[@]}" "''${stack_dir##*/}")
          done
          ct_sort_order curr_order
          ct_stop_service "''${curr_order[@]}"
        }

        ct_pull_restart_containers () {
          curr_order=()
          for stack_dir in "$DOCKER_COMPOSE_STACK_DATA_PATH"/*/ ; do
            if [ "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST" != "$stack_dir" ] && [ -s "$stack_dir"/*compose.yml ]; then
              curr_order=("''${curr_order[@]}" "$stack_dir")
            fi
          done
          if [ "''${1:-}" = restart ] ; then
            ct_pull_restart "''${curr_order[@]}"
          else
            ct_pull_images "''${curr_order[@]}"
          fi
        }

        ct_restart_app_containers () {
          curr_order=()
          for stack_dir in "$DOCKER_COMPOSE_STACK_DATA_PATH"/*/ ; do
            if [ "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST" != "$stack_dir" ] && [ -s "$stack_dir"/*compose.yml ]; then
              curr_order=("''${curr_order[@]}" "$stack_dir")
            fi
          done
          ct_restart "''${curr_order[@]}"
        }

        ct_stop_app_containers () {
          curr_order=()
          for stack_dir in "$DOCKER_COMPOSE_STACK_DATA_PATH"/*/ ; do
            if [ "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST" != "$stack_dir" ] && [ -s "$stack_dir"/*compose.yml ]; then
              curr_order=("''${curr_order[@]}" "$stack_dir")
            fi
          done
          ct_stop "''${curr_order[@]}"
        }

        ct_restart_first () {
          if [ -s "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml ]; then
            echo "**** [container-tool] [restart_first] Bringing down stack - $DOCKER_COMPOSE_STACK_DATA_PATH$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"
            $docker_compose_bin -f "$DOCKER_COMPOSE_STACK_DATA_PATH"/"$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
            echo "**** [container-tool] [restart_first] Bringing up stack - $DOCKER_COMPOSE_STACK_DATA_PATH$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"
            $docker_compose_bin -f "$DOCKER_COMPOSE_STACK_DATA_PATH"/"$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml up -d
          fi
        }

        ct_restart_sssd() {
          if ${pkgs.procps}/bin/pgrep -x "sssd" >/dev/null ; then
              echo "**** [container-tool] Restarting SSSD"
              $dsudo systemctl restart sssd
          fi
        }

        if [ "$#" -gt 2 ] || { [ "$#" -eq 2 ] && [ "''${2-}" != "--debug" ]; } then
          echo $"Usage:"
          echo "  $0 {core|applications|shutdown|pull|apps|--all}"
          echo "  $0 -h|--help"
          exit 1
        fi

        if [ "''${2-}" = "--debug" ]; then
          set -x
        fi

        case "''${1-}" in
          core|system)
            echo "**** [container-tool] Restarting Core Applications"
            ct_restart_first           # Restart $DOCKER_COMPOSE_STACK_APP_RESTART_FIRST
            ct_restart_sys_containers  # Restart $DOCKER_STACK_SYSTEM_DATA_PATH
            ct_restart_sssd
          ;;
          applications|apps)
            echo "**** [container-tool] Restarting User Applications"
            ct_restart_app_containers  # Restart $DOCKER_COMPOSE_STACK_DATA_PATH
            ct_restart_sssd
          ;;
          --all|-a)
            echo "**** [container-tool] Restarting all Containers"
            ct_restart_first
            ct_restart_sys_containers
            ct_restart_app_containers
            ct_restart_sssd
          ;;
          pull)
            if [ "''${2-}" = "restart" ] ; then pull_str=" AND restarting containers " ; fi
            echo "**** [container-tool] Pulling all images ''${pull_str:-} for compose.yml files (!= .norestart)"
            ct_pull_restart_containers ''${2-}
          ;;
          shutdown)
            if [ "''${2-}" = "nobackup" ] ; then shutdown_str=" NOT " ; fi
            echo "**** [container-tool] Stopping all compose stacks and''${shutdown_str:-}backing up databases if a db-backup container exists"
            ct_stop_stack
          ;;
          stop)
            echo "**** [container-tool] Stopping all containers"
            ct_stop_sys_containers
            ct_stop_app_containers
          ;;
          --help|-h)
            echo "Usage:"
            echo "  contianer-tool {core|applications|shutdown|pull|apps|--all}"
            echo
            echo "  core|system          restart auth and system containers"
            echo "  applications|apps    restart application containers"
            echo "  pull (restart)       pull images with updates. Add restart as second argument to immediately restart"
            echo "  shutdown (nobackup)  Shutdown all docker-compose stacks regardless of what they are - add nobackup argument to skip backing up DB"
            echo "  stop                 stop all containers"
            echo "  --all|-a             restart all core and application containers"
          ;;
          *)
            echo $"Usage:"
            echo "  container-tool {core|applications|apps|pull|shutdown|stop|--all}"
            echo "  container-tool -h|--help"
          ;;
        esac
      '')
    ];

    systemd = {
      services = mkIf service.enable {
        docker-container-manager-boot = {
          enable = true;
          description = "Start docker containers on boot";
          after = [ "docker.service" ];
          serviceConfig = {
            Type = "oneshot";
            # Run only on recent boots (uptime < 300s). Use awk to return 0 when uptime < 300.
            ExecCondition = "${pkgs.gawk}/bin/awk '{exit (int($1) >= 300)}' /proc/uptime";
            ExecStart = [
              "/bin/sh -c 'echo \"Executing system startup container management tasks\"'"
              "/run/current-system/sw/bin/container-tool stop"
              "/run/current-system/sw/bin/container-tool core"
              "/run/current-system/sw/bin/container-tool apps"
            ];
            RemainAfterExit = "no";
            TimeoutSec = 900;
          };
          wantedBy = [ "multi-user.target" ];
        };

        docker-container-manager-shutdown = {
          enable = true;
          description = "Stop docker containers on shutdown";
          before = [ "docker.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecCondition = "/usr/bin/test -e /run/systemd/shutdown/ready";
            ExecStart = [
              "/bin/sh -c 'echo \"Executing system shutdown container management tasks\"'"
              "/run/current-system/sw/bin/container-tool shutdown"
            ];
            RemainAfterExit = "no";
            TimeoutSec = 900;
          };
          wantedBy = [ "shutdown.target" ];
        };
      };
    };
  };
}