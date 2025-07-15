{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.host.feature.virtualization.docker.script.compose2nix;
in
{
  options = {
    host.feature.virtualization.docker.script.compose2nix = {
      enable = mkOption {
        default = config.host.feature.virtualization.docker.enable;
        type = with types; bool;
        description = "Enables Compose2Nix script for converting Docker Compose files to NixOS container configurations.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "compose2nix" ''
        set -euo pipefail

        # Check dependencies
        command -v ${yq-go}/bin/yq >/dev/null 2>&1 || { echo "Error: yq is required but not installed." >&2; exit 1; }

        # Default values
        COMPOSE_FILE=""
        OUTPUT_FILE=""

        # Parse arguments
        show_help() {
          cat << EOF
Usage: compose2nix <compose.yml> [output-file.nix]

Convert a compose.yml file to NixOS container configuration.

Arguments:
  <compose.yml>     Path to the compose file
  [output-file.nix] Optional output file

Options:
  -h, --help        Show this help message

Examples:
  compose2nix compose.yml
  compose2nix app/compose.yml containers.nix
  compose2nix stack.yml > ./stack.nix
EOF
        }

        if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
          show_help
          exit 0
        fi

        COMPOSE_FILE="$1"
        OUTPUT_FILE="''${2:-}"

        # Validate input file
        if [[ ! -f "$COMPOSE_FILE" ]]; then
          echo "Error: File '$COMPOSE_FILE' not found!" >&2
          exit 1
        fi

        # Helper functions
        normalize_name() {
          echo "$1" | ${gnused}/bin/sed 's/[^a-zA-Z0-9_-]/_/g' | ${gnused}/bin/sed 's/^[0-9]/_&/'
        }

        parse_ports() {
          local ports="$1"
          if [[ -z "$ports" || "$ports" == "null" ]]; then
            echo "        ports = [];"
            return
          fi

          echo "        ports = ["
          echo "$ports" | ${yq-go}/bin/yq eval '.[]' - | while IFS= read -r port; do
            if [[ "$port" =~ ^([0-9]+):([0-9]+)$ ]]; then
              host_port="''${BASH_REMATCH[1]}"
              container_port="''${BASH_REMATCH[2]}"
              echo "          {"
              echo "            host = \"$host_port\";"
              echo "            container = \"$container_port\";"
              echo "            method = \"interface\";  # or \"zerotier\", \"address\""
              echo "            # excludeInterfaces = [ \"lo\" \"zt0\" ];"
              echo "            # excludeInterfacePattern = \"docker|veth|br-\";"
              echo "            # zerotierNetwork = \"your-network-id\";"
              echo "          }"
            elif [[ "$port" =~ ^([0-9\.]+):([0-9]+):([0-9]+)$ ]]; then
              bind_ip="''${BASH_REMATCH[1]}"
              host_port="''${BASH_REMATCH[2]}"
              container_port="''${BASH_REMATCH[3]}"
              echo "          {"
              echo "            host = \"$host_port\";"
              echo "            container = \"$container_port\";"
              echo "            method = \"address\";"
              echo "            address = \"$bind_ip\";"
              echo "          }"
            else
              echo "          # TODO: Parse complex port: $port"
            fi
          done
          echo "        ];"
        }

        parse_volumes() {
          local volumes="$1"
          if [[ -z "$volumes" || "$volumes" == "null" ]]; then
            echo "        volumes = [];"
            return
          fi

          echo "        volumes = ["
          echo "$volumes" | ${yq-go}/bin/yq eval '.[]' - | while IFS= read -r volume; do
            if [[ "$volume" =~ ^([^:]+):([^:]+)(:([^:]+))?$ ]]; then
              source="''${BASH_REMATCH[1]}"
              target="''${BASH_REMATCH[2]}"
              options="''${BASH_REMATCH[4]:-}"

              echo "          {"
              echo "            source = \"$source\";"
              echo "            target = \"$target\";"
              [[ -n "$options" ]] && echo "            options = \"$options\";"
              echo "            createIfMissing = true;"
              echo "            permissions = \"755\";"
              echo "          }"
            else
              echo "          # TODO: Parse complex volume: $volume"
            fi
          done
          echo "        ];"
        }

        parse_environment() {
          local env="$1"
          if [[ -z "$env" || "$env" == "null" ]]; then
            echo "        environment = {};"
            return
          fi

          echo "        environment = {"

          # Check type - yq-go returns !!seq for arrays, !!map for objects
          env_type=$(echo "$env" | ${yq-go}/bin/yq eval 'type' - 2>/dev/null)
          if [[ "$env_type" == "!!map" ]]; then
            echo "$env" | ${yq-go}/bin/yq eval 'to_entries[] | "          \"" + .key + "\" = \"" + (.value | tostring) + "\";"' -
          elif [[ "$env_type" == "!!seq" ]]; then
            echo "$env" | ${yq-go}/bin/yq eval '.[]' - | while IFS= read -r env_var; do
              if [[ "$env_var" =~ ^([^=]+)=(.*)$ ]]; then
                key="''${BASH_REMATCH[1]}"
                value="''${BASH_REMATCH[2]}"
                echo "          \"$key\" = \"$value\";"
              elif [[ -n "$env_var" ]]; then
                echo "          # TODO: Parse environment variable without value: $env_var"
              fi
            done
          else
            echo "          # TODO: Parse environment (unknown format): $env"
          fi
          echo "        };"
        }

        parse_networks() {
          local networks="$1"
          if [[ -z "$networks" || "$networks" == "null" ]]; then
            echo "        networking.networks = [ \"services\" ];"
            return
          fi

          # Check type - yq-go returns !!seq for arrays, !!map for objects
          network_type=$(echo "$networks" | ${yq-go}/bin/yq eval 'type' - 2>/dev/null)
          if [[ "$network_type" == "!!seq" ]]; then
            network_list=$(echo "$networks" | ${yq-go}/bin/yq eval '.[]' - | tr '\n' ' ' | ${gnused}/bin/sed 's/[[:space:]]*$//')
            if [[ -n "$network_list" ]]; then
              formatted_list=$(echo "$network_list" | ${gnused}/bin/sed 's/ /" "/g' | ${gnused}/bin/sed 's/^/"/' | ${gnused}/bin/sed 's/$/"/')
              echo "        networking.networks = [ $formatted_list ];"
            else
              echo "        networking.networks = [ \"services\" ];"
            fi
          else
            network_list=$(echo "$networks" | ${yq-go}/bin/yq eval 'keys[]' - | tr '\n' ' ' | ${gnused}/bin/sed 's/[[:space:]]*$//')
            if [[ -n "$network_list" ]]; then
              formatted_list=$(echo "$network_list" | ${gnused}/bin/sed 's/ /" "/g' | ${gnused}/bin/sed 's/^/"/' | ${gnused}/bin/sed 's/$/"/')
              echo "        networking.networks = [ $formatted_list ];"
            else
              echo "        networking.networks = [ \"services\" ];"
            fi
          fi
        }

        parse_labels() {
          local labels="$1"
          if [[ -z "$labels" || "$labels" == "null" || "$labels" == "" ]]; then
            echo "        labels = {};"
            return
          fi

          echo "        labels = {"

          # Check type - yq-go returns !!seq for arrays, !!map for objects
          label_type=$(echo "$labels" | ${yq-go}/bin/yq eval 'type' - 2>/dev/null)
          if [[ "$label_type" == "!!seq" ]]; then
            echo "$labels" | ${yq-go}/bin/yq eval '.[]' - | while IFS= read -r label; do
              if [[ "$label" =~ ^([^=]+)=(.*)$ ]]; then
                key="''${BASH_REMATCH[1]}"
                value="''${BASH_REMATCH[2]}"
                echo "          \"$key\" = \"$value\";"
              elif [[ -n "$label" ]]; then
                echo "          # TODO: Parse label without value: $label"
              fi
            done
          elif [[ "$label_type" == "!!map" ]]; then
            echo "$labels" | ${yq-go}/bin/yq eval 'to_entries[] | "          \"" + .key + "\" = \"" + .value + "\";"' -
          else
            echo "          # TODO: Parse labels (unknown format): $labels"
          fi
          echo "        };"
        }

        parse_resources() {
          local deploy="$1"
          if [[ -z "$deploy" || "$deploy" == "null" ]]; then
            return
          fi

          local cpu_limit mem_limit mem_reservation
          cpu_limit=$(echo "$deploy" | ${yq-go}/bin/yq eval '.resources.limits.cpus // ""' -)
          mem_limit=$(echo "$deploy" | ${yq-go}/bin/yq eval '.resources.limits.memory // ""' -)
          mem_reservation=$(echo "$deploy" | ${yq-go}/bin/yq eval '.resources.reservations.memory // ""' -)

          if [[ -n "$cpu_limit" || -n "$mem_limit" || -n "$mem_reservation" ]]; then
            echo "        resources = {"
            [[ -n "$cpu_limit" ]] && echo "          cpus = \"$cpu_limit\";"
            if [[ -n "$mem_limit" || -n "$mem_reservation" ]]; then
              echo "          memory = {"
              [[ -n "$mem_limit" ]] && echo "            max = \"$mem_limit\";"
              [[ -n "$mem_reservation" ]] && echo "            reserve = \"$mem_reservation\";"
              echo "          };"
            fi
            echo "        };"
          fi
        }

        # Main conversion function
        convert_compose_to_nix() {
          local compose_file="$1"
          local output_file="$2"

          # Determine output destination
          if [[ -n "$output_file" ]]; then
            exec 3>"$output_file"
            output_fd=3
            echo_to_stderr() { echo "$@" >&2; }
          else
            exec 3>&1
            output_fd=3
            echo_to_stderr() { echo "$@" >&2; }
          fi

          cat >&$output_fd << 'EOF'
# Generated from compose.yml by compose2nix
# Edit as needed for your specific configuration

{ config, lib, pkgs, ... }:

{
  host.feature.virtualization.docker.containers = {
EOF

          # Get all services
          services=$(${yq-go}/bin/yq eval '.services | keys[]' - < "$compose_file")

          while IFS= read -r service; do
            normalized_name=$(normalize_name "$service")

            echo_to_stderr "Processing service: $service -> $normalized_name"

            # Extract service configuration
            service_config=$(${yq-go}/bin/yq eval ".services.\"$service\"" - < "$compose_file")

            # Basic container configuration
            cat >&$output_fd << EOF

    $normalized_name = {
      enable = true;  # Set to false to disable this container

EOF

            # Parse image
            image=$(echo "$service_config" | ${yq-go}/bin/yq eval '.image // ""' -)
            if [[ -n "$image" ]]; then
              if [[ "$image" =~ ^([^:]+):(.+)$ ]]; then
                image_name="''${BASH_REMATCH[1]}"
                image_tag="''${BASH_REMATCH[2]}"
                echo "        image = {"
                echo "          name = \"$image_name\";"
                echo "          tag = \"$image_tag\";"
                echo "        };"
              else
                echo "        image.name = \"$image\";"
              fi
            fi >&$output_fd

            # Parse hostname
            hostname=$(echo "$service_config" | ${yq-go}/bin/yq eval '.hostname // ""' -)
            [[ -n "$hostname" ]] && echo "        hostname = \"$hostname\";" >&$output_fd

            # Parse container_name
            container_name=$(echo "$service_config" | ${yq-go}/bin/yq eval '.container_name // ""' -)
            [[ -n "$container_name" ]] && echo "        containerName = \"$container_name\";" >&$output_fd

            # Parse user
            user=$(echo "$service_config" | ${yq-go}/bin/yq eval '.user // ""' -)
            [[ -n "$user" ]] && echo "        user = \"$user\";" >&$output_fd

            # Parse working directory
            working_dir=$(echo "$service_config" | ${yq-go}/bin/yq eval '.working_dir // ""' -)
            [[ -n "$working_dir" ]] && echo "        workdir = \"$working_dir\";" >&$output_fd

            # Parse privileged mode
            privileged=$(echo "$service_config" | ${yq-go}/bin/yq eval '.privileged // false' -)
            [[ "$privileged" == "true" ]] && echo "        privileged = true;" >&$output_fd

            # Parse resource limits
            deploy=$(echo "$service_config" | ${yq-go}/bin/yq eval '.deploy // ""' -)
            parse_resources "$deploy" | while IFS= read -r line; do echo "$line" >&$output_fd; done

            # Parse labels
            if echo "$service_config" | ${yq-go}/bin/yq eval 'has("labels")' - 2>/dev/null | grep -q "true"; then
              labels=$(echo "$service_config" | ${yq-go}/bin/yq eval '.labels' -)
              parse_labels "$labels" >&$output_fd
            else
              echo "        labels = {};" >&$output_fd
            fi

            # Parse ports
            if echo "$service_config" | ${yq-go}/bin/yq eval 'has("ports")' - 2>/dev/null | grep -q "true"; then
              ports=$(echo "$service_config" | ${yq-go}/bin/yq eval '.ports' -)
              parse_ports "$ports" >&$output_fd
            else
              echo "        ports = [];" >&$output_fd
            fi

            # Parse volumes
            if echo "$service_config" | ${yq-go}/bin/yq eval 'has("volumes")' - 2>/dev/null | grep -q "true"; then
              volumes=$(echo "$service_config" | ${yq-go}/bin/yq eval '.volumes' -)
              parse_volumes "$volumes" >&$output_fd
            else
              echo "        volumes = [];" >&$output_fd
            fi

            # Parse environment
            if echo "$service_config" | ${yq-go}/bin/yq eval 'has("environment")' - 2>/dev/null | grep -q "true"; then
              environment=$(echo "$service_config" | ${yq-go}/bin/yq eval '.environment' -)
              parse_environment "$environment" >&$output_fd
            else
              echo "        environment = {};" >&$output_fd
            fi

            # Parse networks
            if echo "$service_config" | ${yq-go}/bin/yq eval 'has("networks")' - 2>/dev/null | grep -q "true"; then
              networks=$(echo "$service_config" | ${yq-go}/bin/yq eval '.networks' -)
              parse_networks "$networks" >&$output_fd
            else
              echo "        networking.networks = [ \"services\" ];" >&$output_fd
            fi

            # Parse depends_on
            depends_on=$(echo "$service_config" | ${yq-go}/bin/yq eval '.depends_on // ""' -)
            if [[ -n "$depends_on" && "$depends_on" != "null" ]]; then
              echo -n "        dependsOn = [ "
              depend_type=$(echo "$depends_on" | ${yq-go}/bin/yq eval 'type' - 2>/dev/null)
              if [[ "$depend_type" == "!!seq" ]]; then
                echo "$depends_on" | ${yq-go}/bin/yq eval '.[]' - | while read -r dep; do
                  echo -n "\"$(normalize_name "$dep")\" "
                done
              else
                echo "$depends_on" | ${yq-go}/bin/yq eval 'keys[]' - | while read -r dep; do
                  echo -n "\"$(normalize_name "$dep")\" "
                done
              fi
              echo "];"
            fi >&$output_fd

            echo "      };" >&$output_fd

          done <<< "$services"

          # Close the configuration
          cat >&$output_fd << EOF
    };
  }
EOF

        # Close file descriptor if writing to file
        if [[ -n "$output_file" ]]; then
          exec 3>&-
          echo_to_stderr "Conversion complete! Output written to: $output_file"
        else
          echo_to_stderr "Conversion complete!"
        fi
      }

      # Execute conversion
      convert_compose_to_nix "$COMPOSE_FILE" "$OUTPUT_FILE"
    '')
    ];
  };
}
