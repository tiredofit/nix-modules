{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.host.feature.virtualization.docker.compose;
in
{
  options = {
    host.feature.virtualization.docker.compose = {
      enable = mkOption {
        default = config.host.feature.virtualization.docker.enable;
        type = with types; bool;
        description = "Enables docker compose utility and associated aliases";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      unstable.docker-compose
      (writeShellScriptBin "container-tool" ''
        set -euo pipefail

        export DOCKER_COMPOSE_TIMEOUT=${toString config.host.feature.virtualization.docker.daemon.shutdownTimeout}
        export DOCKER_COMPOSE_TIMEOUT=''${DOCKER_TIMEOUT:-"120"}
        docker_bin_location="$(which docker)"
        docker_compose_bin_location="$(which docker-compose)"

        if id -nG "$USER" | grep -qw "docker" || [ $(id -u) = "0" ]; then
          dsudo=""
        else
          dsudo='sudo'
        fi

        DOCKER_COMPOSE_STACK_DATA_PATH=''${DOCKER_COMPOSE_STACK_DATA_PATH:-"/var/local/data/"}
        DOCKER_STACK_SYSTEM_DATA_PATH=''${DOCKER_STACK_SYSTEM_DATA_PATH:-"/var/local/data/_system/"}
        DOCKER_COMPOSE_STACK_APP_RESTART_FIRST=''${DOCKER_COMPOSE_STACK_APP_RESTART_FIRST:-"auth.example.com"}
        DOCKER_STACK_SYSTEM_APP_RESTART_ORDER=''${DOCKER_STACK_SYSTEM_APP_RESTART_ORDER:-"socket-proxy tinc error-pages traefik unbound openldap postfix-relay llng-handler restic clamav zabbix"}

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
              $docker_compose_bin_location -f "$stack_dir"/*compose.yml pull
            else
              echo "**** [container-tool] [pull] Skipping - $stack_dir"
            fi
          done
        }

        ct_pull_restart () {
          for stack_dir in "$@" ; do
            if [ ! -f "$stack_dir"/.norestart ]; then
              echo "**** [container-tool] [pull_restart] Pulling Images - $stack_dir"
              $docker_compose_bin_location -f "$stack_dir"/*compose.yml pull
              echo "**** [container-tool] [pull_restart] Bringing up stack - $stack_dir"
              $docker_compose_bin_location -f "$stack_dir"/*compose.yml up -d
            else
              echo "**** [container-tool] [pull_restart] Skipping - $stack_dir"
            fi
          done
        }

        ct_restart () {
          for stack_dir in "$@" ; do
            if [ ! -f "$stack_dir"/.norestart ]; then
              echo "**** [container-tool] [restart] Bringing down stack - $stack_dir"
              $docker_compose_bin_location -f "$stack_dir"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
              echo "**** [container-tool] [restart] Bringing up stack - $stack_dir"
              $docker_compose_bin_location -f "$stack_dir"/*compose.yml up -d
            else
              echo "**** [container-tool] [restart] Skipping - $stack_dir"
            fi
          done
        }

        ct_restart_service () {
          for stack_dir in "$@" ; do
            if [ ! -f "$stack_dir"/.norestart ]; then
              if systemctl list-unit-files docker-"$stack_dir".service &>/dev/null ; then
                echo "**** [container-tool] [restart] Bringing down stack - $stack_dir"
                systemctl stop docker-"$stack_dir".service
                echo "**** [container-tool] [restart] Bringing up stack - $stack_dir"
                systemctl start docker-"$stack_dir".service
              else
                echo "**** [container-tool] [restart] Skipping - $stack_dir"
              fi
            fi
          done
        }

        ct_stop () {
          for stack_dir in "$@" ; do
            echo "**** [container-tool] [stop] Stopping stack - $stack_dir"
            $docker_compose_bin_location -f "$stack_dir"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
          done
        }

        ct_stop_service() {
          for stack_dir in "$@" ; do
            if systemctl list-unit-files docker-"$stack_dir".service &>/dev/null ; then
              echo "**** [container-tool] [stop_service] Stopping stack - $stack_dir"
              systemctl stop docker-"$stack_dir".service
            fi
          done
        }

        ct_sort_order () {
          local -n tmparr=$1
          index=0

          for i in ''${!predef_order[*]} ; do
            for j in ''${!tmparr[*]} ; do
              tmpitem="''${tmparr[$j]}"
              if [ ''${predef_order[$i]} == $(basename "''${tmpitem::-1}") ]; then
                tmpitem=''${tmparr[$index]}
                tmparr[$index]="''${tmparr[$j]}"
                tmparr[$j]=$tmpitem
                let "index++"
                break
              fi
            done
          done
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
          stacks=$($docker_compose_bin_location ls | tail -n +2 |  ${pkgs.gnused}/bin/awk '{print $1}')
          for stack in $stacks; do
            stack_image=$($docker_compose_bin_location -p $stack images | tail -n +2 |  ${pkgs.gnused}/bin/awk '{print $1,$2}' | grep "db-backup")
            if [ "$1" != "nobackup" ] ; then
              if [[ $stack_image =~ .*"db-backup".* ]] ; then
                stack_container_name=$(echo "$stack_image" |  ${pkgs.gawk}/bin/awk '{print $1}')
                echo "** Backing up database for '$stack_container_name' before stopping"
                $docker_bin_location exec $stack_container_name /usr/local/bin/backup-now
              fi
            fi
            echo "** Gracefully stopping compose stack: $stack"
            $docker_compose_bin_location -p $stack down --timeout $DOCKER_COMPOSE_TIMEOUT
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
          if [ "$1" = restart ] ; then
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
            $docker_compose_bin_location -f "$DOCKER_COMPOSE_STACK_DATA_PATH"/"$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
            echo "**** [container-tool] [restart_first] Bringing up stack - $DOCKER_COMPOSE_STACK_DATA_PATH$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"
            $docker_compose_bin_location -f "$DOCKER_COMPOSE_STACK_DATA_PATH"/"$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml up -d
          fi
        }

        if [ "$#" -gt 2 ] || { [ "$#" -eq 2 ] && [ "$2" != "--debug" ]; } then
          echo $"Usage:"
          echo "  $0 {core|applications|shutdown|pull|apps|--all}"
          echo "  $0 -h|--help"
          exit 1
        fi

        if [ "$2" = "--debug" ]; then
          set -x
        fi

        case "$1" in
          core|system)
            echo "**** [container-tool] Restarting Core Applications"
            ct_restart_first           # Restart $DOCKER_COMPOSE_STACK_APP_RESTART_FIRST
            ct_restart_sys_containers  # Restart $DOCKER_STACK_SYSTEM_DATA_PATH
            if pgrep -x "sssd" >/dev/null ; then
              echo "**** [container-tool] Restarting SSSD"
              systemctl restart sssd
            fi
            ;;
          applications|apps)
            echo "**** [container-tool] Restarting User Applications"
            ct_restart_app_containers  # Restart $DOCKER_COMPOSE_STACK_DATA_PATH
            if pgrep -x "sssd" >/dev/null ; then
              echo "**** [container-tool] Restarting SSSD"
              systemctl restart sssd
            fi
            ;;
          --all|-a)
            echo "**** [container-tool] Restarting all Containers"
            ct_restart_first
            ct_restart_sys_containers
            ct_restart_app_containers
            if pgrep -x "sssd" >/dev/null ; then
              echo "**** [container-tool] Restarting SSSD"
              systemctl restart sssd
            fi
            ;;
          pull)
            if [ "$2" = "restart" ] ; then pull_str="and restarting containers" ; fi
            echo "**** [container-tool] Pulling all images $pull_str for compose.yml files (!= .norestart)"
            ct_pull_restart_containers $2
            ;;
          shutdown)
            if [ "$2" = "nobackup" ] ; then shutdown_str="NOT" ; fi
            echo "**** [container-tool] Stopping all compose stacks and $shutdown_str backing up databases if a db-backup container exists"
            ct_stop_stack
            ;;
          stop)
            echo "**** [container-tool] Stopping all containers"
            ct_stop_sys_containers
            ct_stop_app_containers
            ;;
          --help|-h)
            echo $"Usage:"
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

    programs = {
      bash = {
        interactiveShellInit = ''
          docker_compose_bin_location="$(which docker-compose)"
          export DOCKER_COMPOSE_TIMEOUT=''${DOCKER_TIMEOUT:-"120"}

          docker-compose() {
           if [ "$2" != "--help" ] ; then
             case "$1" in
               "down" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin_location down --timeout $DOCKER_COMPOSE_TIMEOUT $arg
               ;;
               "restart" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin_location restart --timeout $DOCKER_COMPOSE_TIMEOUT $arg
               ;;
               "stop" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin_location stop --timeout $DOCKER_COMPOSE_TIMEOUT $arg
               ;;
               "up" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin_location up $arg
               ;;
               * )
                 $dsudo $docker_compose_bin_location ''${@}
               ;;
            esac
           fi
          }

          alias container-tool=container_tool
          alias dcpull='$dsudo docker-compose pull'                                                                                        # Docker Compose Pull
          alias dcu='$dsudo $docker_compose_bin_location up'                                                                                   # Docker Compose Up
          alias dcud='$dsudo $docker_compose_bin_location up -d'                                                                               # Docker Compose Daemonize
          alias dcd='$dsudo $docker_compose_bin_location down --timeout $DOCKER_COMPOSE_TIMEOUT'                                               # Docker Compose Down
          alias dcl='$dsudo $docker_compose_bin_location logs -f'                                                                              # Docker Compose Logs
          alias dcrecycle='$dsudo $docker_compose_bin_location down --timeout $DOCKER_COMPOSE_TIMEOUT ; $dsudo $docker_compose_bin_location up -d' # Docker Compose Restart
        '';
      };
    };
  };
}
