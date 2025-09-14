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
    ];

    programs = {
      bash = {
        interactiveShellInit = ''
          docker_compose_bin="$(command -v docker-compose)"
          export DOCKER_COMPOSE_TIMEOUT=''${DOCKER_TIMEOUT:-"120"}

          docker-compose() {
           if [ "$2" != "--help" ] ; then
             case "$1" in
               "down" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin down --timeout $DOCKER_COMPOSE_TIMEOUT $arg
               ;;
               "restart" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin restart --timeout $DOCKER_COMPOSE_TIMEOUT $arg
               ;;
               "stop" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin stop --timeout $DOCKER_COMPOSE_TIMEOUT $arg
               ;;
               "up" )
                 arg=$(echo "$@" | ${pkgs.gnused}/bin/sed "s|^$1||g")
                 $dsudo $docker_compose_bin up $arg
               ;;
               * )
                 $dsudo $docker_compose_bin ''${@}
               ;;
            esac
           fi
          }

          alias dcpull='$dsudo docker-compose pull'                                                                                        # Docker Compose Pull
          alias dcu='$dsudo $docker_compose_bin up'                                                                                   # Docker Compose Up
          alias dcud='$dsudo $docker_compose_bin up -d'                                                                               # Docker Compose Daemonize
          alias dcd='$dsudo $docker_compose_bin down --timeout $DOCKER_COMPOSE_TIMEOUT'                                               # Docker Compose Down
          alias dcl='$dsudo $docker_compose_bin logs -f'                                                                              # Docker Compose Logs
          alias dcrecycle='$dsudo $docker_compose_bin down --timeout $DOCKER_COMPOSE_TIMEOUT ; $dsudo $docker_compose_bin up -d' # Docker Compose Restart
        '';
      };
    };
  };
}
