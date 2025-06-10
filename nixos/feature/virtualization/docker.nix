{config, lib, pkgs, ...}:

with lib;
let
  cfg = config.host.feature.virtualization.docker;

  docker_storage_driver =
    if config.host.filesystem.btrfs.enable
    then "btrfs"
    else "overlay2";

  # Container type definition from containers-fixed.nix
  containerType = types.submodule ({ name, config, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable this container";
      };

      image = {
        name = mkOption {
          type = types.str;
          description = "Container image name";
        };
        tag = mkOption {
          type = types.str;
          default = "latest";
          description = "Container image tag";
        };
        registry = mkOption {
          type = types.str;
          default = "docker.io";
          description = "Container registry";
        };
        pullOnStart = mkOption {
          type = types.bool;
          default = true;
          description = "Pull image on service start";
        };
      };

      resources = {
        cpus = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "CPU limit (null for no limit)";
        };
        memory = {
          max = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Maximum memory limit (null for no limit)";
          };
          reserve = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Memory reservation (null for no reservation)";
          };
        };
      };

      networking = {
        networks = mkOption {
          type = types.listOf types.str;
          default = [ "services" ];
          description = "Docker networks to join";
        };
        dns = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "DNS server for container";
        };
        ip = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Fixed IP address for container (requires custom network)";
        };
      };

      volumes = mkOption {
        type = types.listOf (types.submodule {
          options = {
            source = mkOption {
              type = types.str;
              description = "Host path for volume mount";
            };
            target = mkOption {
              type = types.str;
              description = "Container path for volume mount";
            };
            options = mkOption {
              type = types.str;
              default = "";
              description = "Volume mount options (e.g., 'ro', 'rw')";
            };
            createIfMissing = mkOption {
              type = types.bool;
              default = true;
              description = "Create directory if it doesn't exist";
            };
            removeCOW = mkOption {
              type = types.bool;
              default = false;
              description = "Remove copy-on-write attribute (chattr +C)";
            };
            owner = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Owner for created directory (user:group or user)";
            };
            permissions = mkOption {
              type = types.str;
              default = "755";
              description = "Permissions for created directory";
            };
          };
        });
        default = [ ];
        description = "Volume mounts with creation options";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables";
      };

      environmentFiles = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "Environment files for this container.";
        example = [
          /path/to/.env
          /path/to/.env.secret
        ];
      };

      entrypoint = mkOption {
        type = types.nullOr types.str;
        description = "Overwrite the default entrypoint of the image.";
        default = null;
        example = "/bin/my-app";
      };

      cmd = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Commandline arguments to pass to the image's entrypoint.";
        example = ["--port=9000"];
      };

      workdir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override the default working directory for the container.";
        example = "/var/lib/hello_world";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override the username or UID (and optionally groupname or GID) used in the container.";
        example = "nobody:nogroup";
      };

      secrets = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable SOPS secrets for this container to be passed as environment variables";
        };
        files = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of secret file paths to include";
        };
        autoDetect = mkOption {
          type = types.bool;
          default = true;
          description = "Automatically detect and include common secret files if they exist";
        };
      };

      logging = {
        driver = mkOption {
          type = types.str;
          default = "local";
          description = "Docker logging driver";
        };
      };

      # Security and device options
      privileged = mkOption {
        type = types.bool;
        default = false;
        description = "Run container in privileged mode";
      };

      capabilities = {
        add = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Linux capabilities to add to the container";
        };
        drop = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Linux capabilities to drop from the container";
        };
      };

      devices = mkOption {
        type = types.listOf (types.submodule {
          options = {
            host = mkOption {
              type = types.str;
              description = "Host device path";
            };
            container = mkOption {
              type = types.str;
              default = "";
              description = "Container device path (defaults to host path if empty)";
            };
            permissions = mkOption {
              type = types.str;
              default = "rwm";
              description = "Device permissions (r/w/m)";
            };
          };
        });
        default = [ ];
        description = "Device mappings for the container";
      };

      extraOptions = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra Docker options";
      };

      labels = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Docker labels for the container";
      };

      # Container hostname
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Container hostname (if null, no hostname is set)";
      };

      containerName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override the container name (defaults to attribute name)";
        example = "my-custom-container-name";
      };

      # Service ordering
      serviceOrder = {
        after = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Services this container should start after";
        };
        before = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Services this container should start before";
        };
      };

      dependsOn = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Define which other containers this one depends on. They will be added to both After and Requires for the unit.";
        example = [
          "container1"
        ];
      };

      # Port binding options
      ports = mkOption {
        type = types.listOf (types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable network-specific IP binding for this port";
            };
            host = mkOption {
              type = types.str;
              description = "Host port to bind";
            };
            container = mkOption {
              type = types.str;
              description = "Container port to map to";
            };
            protocol = mkOption {
              type = types.enum [ "tcp" "udp" ];
              default = "tcp";
              description = "Port protocol (tcp or udp)";
            };
            method = mkOption {
              type = types.enum [ "interface" "address" "pattern" "zerotier" ];
              default = "interface";
              description = "IP resolution method";
            };
            interface = mkOption {
              type = types.str;
              default = "";
              description = "Network interface name";
            };
            interfacePattern = mkOption {
              type = types.str;
              default = "";
              description = "Interface pattern (e.g., eth*)";
            };
            excludeInterfaces = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Interfaces to exclude";
            };
            excludeInterfacePattern = mkOption {
              type = types.str;
              default = "";
              description = "Interface exclusion pattern";
            };
            address = mkOption {
              type = types.str;
              default = "";
              description = "Specific IP address";
            };
            addressPattern = mkOption {
              type = types.str;
              default = "";
              description = "IP address pattern";
            };
            excludeAddressPattern = mkOption {
              type = types.str;
              default = "";
              description = "IP exclusion pattern";
            };
            zerotierNetwork = mkOption {
              type = types.str;
              default = "";
              description = "ZeroTier network ID";
            };
          };
        });
        default = [ ];
        description = "Port bindings with optional network-specific IP binding";
      };
    };
  });

  containercfg = config.host.feature.virtualization.docker.containers;
  proxy_env = config.networking.proxy.envVars;
  hostname = config.host.network.hostname;

  # Helper functions from containers-fixed.nix
  generateEnvironmentFiles = containerName: cfg:
    let
      userFiles = cfg.secrets.files or [];
      autoDetectedFiles = if (cfg.secrets.enable or false) && (cfg.secrets.autoDetect or false) then
        (lib.optional
          (builtins.pathExists "${config.host.configDir}/hosts/common/secrets/container/container-${containerName}.env")
          config.sops.secrets."common-container-${containerName}".path) ++
        (lib.optional
          (builtins.pathExists "${config.host.configDir}/hosts/${hostname}/secrets/container/container-${containerName}.env")
          config.sops.secrets."host-container-${containerName}".path)
      else [];
    in
    userFiles ++ autoDetectedFiles;

  generateSOPSSecrets = containerName: cfg:
    let
      commonSecretExists = builtins.pathExists "${config.host.configDir}/hosts/common/secrets/container/container-${containerName}.env";
      hostSecretExists = builtins.pathExists "${config.host.configDir}/hosts/${hostname}/secrets/container/container-${containerName}.env";
    in
    lib.optionalAttrs ((cfg.enable or false) && (cfg.secrets.enable or false) && (cfg.secrets.autoDetect or false) && commonSecretExists) {
      "common-container-${containerName}" = {
        format = "dotenv";
        sopsFile = "${config.host.configDir}/hosts/common/secrets/container/container-${containerName}.env";
        restartUnits = [ "docker-${containerName}.service" ];
      };
    } //
    lib.optionalAttrs ((cfg.enable or false) && (cfg.secrets.enable or false) && (cfg.secrets.autoDetect or false) && hostSecretExists) {
      "host-container-${containerName}" = {
        format = "dotenv";
        sopsFile = "${config.host.configDir}/hosts/${hostname}/secrets/container/container-${containerName}.env";
        restartUnits = [ "docker-${containerName}.service" ];
      };
    };

  # Generate IP resolution script for a specific port
  ipResolutionScript = containerName: portCfg: ''
    # Resolve IP for method: ${portCfg.method}
    BINDING_IP_${portCfg.host}=""

    case "${portCfg.method}" in
      "zerotier")
        # Handle file:// prefix for zerotier network ID
        ZEROTIER_NETWORK="${portCfg.zerotierNetwork}"
        if [[ "$ZEROTIER_NETWORK" == file://* ]]; then
          NETWORK_FILE="''${ZEROTIER_NETWORK#file://}"
          if [ -f "$NETWORK_FILE" ]; then
            # Read first word of first line from the file
            ZEROTIER_NETWORK=$(head -n1 "$NETWORK_FILE" | ${pkgs.gawk}/bin/awk '{print $1}')
            echo "Read ZeroTier network ID from file $NETWORK_FILE: $ZEROTIER_NETWORK"
          else
            echo "ERROR: ZeroTier network file not found: $NETWORK_FILE"
            exit 1
          fi
        fi

        if [ -n "$ZEROTIER_NETWORK" ]; then
          if ! ${pkgs.zerotierone}/bin/zerotier-cli -p${toString config.services.zerotierone.port} info >/dev/null 2>&1; then
            echo "ERROR: ZeroTier not running"
            exit 1
          fi
          NETWORK_INFO=$(${pkgs.zerotierone}/bin/zerotier-cli -p${toString config.services.zerotierone.port} listnetworks | grep "^200 listnetworks" | grep "$ZEROTIER_NETWORK" || true)
          if [ -n "$NETWORK_INFO" ]; then
            IP=$(echo "$NETWORK_INFO" | ${pkgs.gawk}/bin/awk '{print $NF}' | ${pkgs.gnused}/bin/sed 's/\/.*//')
            if [ -n "$IP" ] && [ "$IP" != "-" ]; then
              BINDING_IP_${portCfg.host}="$IP"
              echo "Found ZeroTier IP for port ${portCfg.host}: $IP (network: $ZEROTIER_NETWORK)"
            fi
          fi
        fi
        ;;
      "interface")
        # Find interface-based IP
        for interface in $(${pkgs.iproute2}/bin/ip -o link show | ${pkgs.gawk}/bin/awk -F': ' '{print $2}'); do
          # Skip excluded interfaces
          ${concatMapStringsSep "\n          " (iface: ''
            if [ "$interface" = "${iface}" ]; then continue; fi'') portCfg.excludeInterfaces}

          # Skip interfaces matching exclusion pattern
          if [ -n "${portCfg.excludeInterfacePattern}" ]; then
            if echo "$interface" | grep -qE "${portCfg.excludeInterfacePattern}"; then
              continue
            fi
          fi

          # Get IP from interface
          IP=$(${pkgs.iproute2}/bin/ip -4 addr show "$interface" | ${pkgs.gawk}/bin/awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1)
          if [ -n "$IP" ]; then
            BINDING_IP_${portCfg.host}="$IP"
            echo "Found interface IP for port ${portCfg.host}: $IP (interface: $interface)"
            break
          fi
        done
        ;;
      "address")
        if [ -n "${portCfg.address}" ]; then
          BINDING_IP_${portCfg.host}="${portCfg.address}"
          echo "Using fixed address for port ${portCfg.host}: ${portCfg.address}"
        fi
        ;;
    esac

  '';

  # Generate volume preparation script
  generateVolumePrep = cfg: ''
    # Prepare volumes
    ${concatMapStringsSep "\n    " (vol: ''
      if [ "${toString vol.createIfMissing}" = "true" ]; then
        if [ ! -d "${vol.source}" ]; then
          echo "Creating volume directory: ${vol.source}"
          mkdir -p "${vol.source}"
          chmod ${vol.permissions} "${vol.source}"
          ${optionalString (vol.owner != null) ''
            chown ${vol.owner} "${vol.source}"
          ''}
        fi
        ${optionalString vol.removeCOW ''
          echo "Removing COW attribute from: ${vol.source}"
          ${pkgs.e2fsprogs}/bin/chattr +C "${vol.source}" 2>/dev/null || true
        ''}
      fi
    '') cfg.volumes}
  '';

  # Generate volume arguments for Docker
  generateVolumeArgs = cfg: concatMapStringsSep " " (vol:
    let
      mountString = "${vol.source}:${vol.target}";
      fullMountString = if vol.options != "" then "${mountString}:${vol.options}" else mountString;
    in
    "--volume ${fullMountString}"
  ) cfg.volumes;

  # Generate port arguments
  generatePortArgs = cfg: ''
    PORT_ARGS=""
    ${concatMapStringsSep "\n    " (portCfg: ''
      if [ "${if portCfg.enable then "true" else "false"}" = "true" ]; then
        echo "Processing port ${portCfg.host} with enable=${if portCfg.enable then "true" else "false"}"
        echo "BINDING_IP_80 value: $BINDING_IP_80"
        echo "BINDING_IP_443 value: $BINDING_IP_443"
        case "${portCfg.host}" in
          "80")
            IP="$BINDING_IP_80"
            echo "Port 80: Using IP from BINDING_IP_80: $IP"
            ;;
          "443")
            IP="$BINDING_IP_443"
            echo "Port 443: Using IP from BINDING_IP_443: $IP"
            ;;
          *)
            eval "IP=\$BINDING_IP_${portCfg.host}"
            echo "Port ${portCfg.host}: Using eval, IP: $IP"
            ;;
        esac
        if [ -n "$IP" ]; then
          PORT_ARGS="$PORT_ARGS -p $IP:${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
          echo "Added port binding: $IP:${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
        else
          PORT_ARGS="$PORT_ARGS -p ${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
          echo "Using default binding for port ${portCfg.host} (no IP found)"
        fi
      else
        PORT_ARGS="$PORT_ARGS -p ${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
        echo "Port ${portCfg.host} not enabled, using default binding"
      fi
    '') cfg.ports}
    echo "Final PORT_ARGS: $PORT_ARGS"
  '';

  # Generate label arguments
  generateLabelArgs = cfg: concatMapStringsSep " " (labelArg: labelArg)
    (mapAttrsToList (k: v:
      let
        # Escape backticks in the value
        escapedValue = builtins.replaceStrings ["`"] ["\\`"] v;
      in
      "--label='${k}=${escapedValue}'"
    ) cfg.labels);

  # Generate device arguments
  generateDeviceArgs = cfg: concatMapStringsSep " " (device:
    let
      containerPath = if device.container != "" then device.container else device.host;
      deviceString = "${device.host}:${containerPath}";
      fullDeviceString = if device.permissions != "rwm" then "${deviceString}:${device.permissions}" else deviceString;
    in
    "--device=${fullDeviceString}"
  ) cfg.devices;

  # Helper function to create systemd service for containers (from old module)
  mkService = name: container: let
    mkAfter = map (x: "docker-${x}.service") (container.serviceOrder.after or []);

    # Generate environment files (including SOPS secrets)
    allEnvironmentFiles = (generateEnvironmentFiles name container) ++ (container.environmentFiles or []);

    # Convert new container format to old format for compatibility
    convertedContainer = {
      image = "${container.image.name}:${container.image.tag}";
      pullonStart = container.image.pullOnStart or true;
      autoStart = true;
      log-driver = container.logging.driver or "local";
      entrypoint = container.entrypoint or null;
      cmd = container.cmd or [];
      user = container.user or null;
      workdir = container.workdir or null;
      dependsOn = (container.serviceOrder.after or []) ++ (container.dependsOn or []);

      # Convert volumes from new format to old format
      volumes = map (vol:
        let
          mountString = "${vol.source}:${vol.target}";
        in
        if vol.options != "" then "${mountString}:${vol.options}" else mountString
      ) container.volumes;

      # Convert ports from new format to old format
      ports = map (port: "${port.host}:${port.container}") container.ports;

      environment = container.environment;
      environmentFiles = allEnvironmentFiles;
      labels = container.labels;
      networks = container.networking.networks;

      # Convert extraOptions
      extraOptions = container.extraOptions
        ++ optional (container.resources.cpus != null) "--cpus=${container.resources.cpus}"
        ++ optional (container.resources.memory.max != null) "--memory=${container.resources.memory.max}"
        ++ optional (container.resources.memory.reserve != null) "--memory-reservation=${container.resources.memory.reserve}"
        ++ optional (container.hostname != null) "--hostname=${container.hostname}"
        ++ optional (container.networking.dns != null) "--dns=${container.networking.dns}"
        ++ optional (container.networking.ip != null) "--ip=${container.networking.ip}"
        ++ optional container.privileged "--privileged"
        ++ optionals (container.capabilities.add != []) (map (cap: "--cap-add=${cap}") container.capabilities.add)
        ++ optionals (container.capabilities.drop != []) (map (cap: "--cap-drop=${cap}") container.capabilities.drop)
        ++ optionals (container.devices != []) (map (device:
            let
              containerPath = if device.container != "" then device.container else device.host;
              deviceString = "${device.host}:${containerPath}";
              fullDeviceString = if device.permissions != "rwm" then "${deviceString}:${device.permissions}" else deviceString;
            in
            "--device=${fullDeviceString}"
          ) container.devices)
        # Only add network alias if not using host networking
        ++ optional (!(elem "host" container.networking.networks)) "--network-alias=${hostname}-${name}";

      login = {
        username = null;
        passwordFile = null;
        registry = container.image.registry;
      };
      imageFile = null;
    };

    isValidLogin = login: login.username != null && login.passwordFile != null && login.registry != null;
  in
    rec {
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "docker.socket" "network-online.target" ] ++ mkAfter;
      requires = after;
      environment = proxy_env;

      preStart = ''
        # Prepare volumes
        ${generateVolumePrep container}
      '';

      serviceConfig = {
        ExecStart = [ "${pkgs.docker}/bin/docker start -a ${name}" ];

        ExecStartPre = [
          "-${pkgs.docker}/bin/docker rm -f ${name}"
        ] ++ optional (convertedContainer.imageFile != null)
          [ "${pkgs.docker}/bin/docker load -i ${convertedContainer.imageFile}" ]
        ++ optional (isValidLogin convertedContainer.login)
          [ "cat ${convertedContainer.login.passwordFile} | \
              ${pkgs.docker}/bin/docker login \
                ${convertedContainer.login.registry} \
                --username ${convertedContainer.login.username} \
                --password-stdin" ]
        ++ optional (convertedContainer.pullonStart && convertedContainer.imageFile == null)
          [ "${pkgs.docker}/bin/docker pull ${convertedContainer.image}" ]
        ++ [
          (
            concatStringsSep " \\\n  " (
              [
                "${pkgs.docker}/bin/docker create"
                "--rm"
                "--name=${name}"
                "--log-driver=${convertedContainer.log-driver}"
              ] ++ optional (convertedContainer.entrypoint != null)
                "--entrypoint=${escapeShellArg convertedContainer.entrypoint}"
              ++ (mapAttrsToList (k: v: "-e ${escapeShellArg k}=${escapeShellArg v}") convertedContainer.environment)
              ++ map (f: "--env-file ${escapeShellArg f}") convertedContainer.environmentFiles
              ++ map (p: "-p ${escapeShellArg p}") convertedContainer.ports
              ++ optional (convertedContainer.user != null) "-u ${escapeShellArg convertedContainer.user}"
              ++ map (v: "-v ${escapeShellArg v}") convertedContainer.volumes
              ++ optional (convertedContainer.workdir != null) "-w ${escapeShellArg convertedContainer.workdir}"
              ++ optional (convertedContainer.networks != []) "--network=${escapeShellArg (builtins.head convertedContainer.networks)}"
              ++ (mapAttrsToList (k: v: "-l ${escapeShellArg k}=${escapeShellArg v}") convertedContainer.labels)
              ++ map escapeShellArg convertedContainer.extraOptions
              ++ [ convertedContainer.image ]
              ++ map escapeShellArg convertedContainer.cmd
            )
          )
        ] ++ map (n: "${pkgs.docker}/bin/docker network connect ${escapeShellArg n} ${name}") (drop 1 convertedContainer.networks);

        ExecStop = ''${pkgs.bash}/bin/sh -c "[ $SERVICE_RESULT = success ] || ${pkgs.docker}/bin/docker stop ${name}"'';
        ExecStopPost = "-${pkgs.docker}/bin/docker rm -f ${name}";

        TimeoutStartSec = 0;
        TimeoutStopSec = 120;
        Restart = "always";
      };
    };

  # Generate container configurations
  containerConfigs = mapAttrs (containerName: cfg:
    let
      hasSpecialPorts = any (port: port.enable) (cfg.ports or []);
    in {
    # Special ports service
    specialPortsService = mkIf ((cfg.enable or false) && hasSpecialPorts) {
      description = "Container ${containerName} with special port bindings";
      after = [ "docker.service" "network.target" ] ++ (cfg.serviceOrder.after or []) ++ optional config.services.zerotierone.enable "zerotierone.service";
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      before = cfg.serviceOrder.before or [];

      preStart = ''
        # Prepare volumes
        ${generateVolumePrep cfg}

        # Use custom container name if specified, otherwise use attribute name
        CONTAINER_NAME="${if cfg.containerName != null then cfg.containerName else containerName}"

        # Stop and remove existing container
        ${config.virtualisation.docker.package}/bin/docker stop "$CONTAINER_NAME" 2>/dev/null || true
        ${config.virtualisation.docker.package}/bin/docker rm "$CONTAINER_NAME" 2>/dev/null || true
      '';

      script = ''
        set -e

        # Use custom container name if specified, otherwise use attribute name
        CONTAINER_NAME="${if cfg.containerName != null then cfg.containerName else containerName}"

        # Resolve IPs for all special ports
        ${concatMapStringsSep "\n        " (portCfg:
          optionalString portCfg.enable (ipResolutionScript containerName portCfg)
        ) cfg.ports}

        # Generate port arguments
        ${generatePortArgs cfg}

        # Generate environment file arguments
        ENV_FILE_ARGS=""
        ${concatMapStringsSep "\n        " (envFile: ''
          if [ -f "${envFile}" ]; then
            ENV_FILE_ARGS="$ENV_FILE_ARGS --env-file=${envFile}"
            echo "Added environment file: ${envFile}"
          else
            echo "Warning: Environment file not found: ${envFile}"
          fi
        '') ((generateEnvironmentFiles containerName cfg) ++ (cfg.environmentFiles or []))}

        exec ${config.virtualisation.docker.package}/bin/docker run --rm --name "$CONTAINER_NAME" \
          ${optionalString (cfg.hostname != null) "--hostname=${cfg.hostname}"} \
          ${optionalString (cfg.workdir or null != null) "--workdir=${cfg.workdir}"} \
          ${optionalString (cfg.user or null != null) "--user=${cfg.user}"} \
          ${optionalString (cfg.entrypoint or null != null) "--entrypoint=${escapeShellArg cfg.entrypoint}"} \
          ${optionalString (cfg.resources.cpus != null) "--cpus=${cfg.resources.cpus}"} \
          ${optionalString (cfg.resources.memory.max != null) "--memory=${cfg.resources.memory.max}"} \
          ${optionalString (cfg.resources.memory.reserve != null) "--memory-reservation=${cfg.resources.memory.reserve}"} \
          ${optionalString cfg.privileged "--privileged"} \
          ${concatMapStringsSep " " (cap: "--cap-add=${cap}") cfg.capabilities.add} \
          ${concatMapStringsSep " " (cap: "--cap-drop=${cap}") cfg.capabilities.drop} \
          ${generateDeviceArgs cfg} \
          ${optionalString (!(elem "host" cfg.networking.networks)) "--network-alias=${hostname}-${containerName}"} \
          ${concatMapStringsSep " " (net: "--network ${net}") cfg.networking.networks} \
          ${generateVolumeArgs cfg} \
          ${concatMapStringsSep " " (envVar: "--env ${escapeShellArg envVar}") (mapAttrsToList (k: v: "${k}=${v}") cfg.environment)} \
          $ENV_FILE_ARGS \
          ${optionalString (cfg.networking.dns != null) "--dns=${cfg.networking.dns}"} \
          ${optionalString (cfg.networking.ip != null) "--ip=${cfg.networking.ip}"} \
          ${generateLabelArgs cfg} \
          ${concatStringsSep " " cfg.extraOptions} \
          ''${PORT_ARGS} \
          ${cfg.image.name}:${cfg.image.tag} \
          ${concatStringsSep " " (map escapeShellArg (cfg.cmd or []))}
      '';

      postStop = ''
        # Use custom container name if specified, otherwise use attribute name
        CONTAINER_NAME="${if cfg.containerName != null then cfg.containerName else containerName}"

        ${config.virtualisation.docker.package}/bin/docker stop "$CONTAINER_NAME" 2>/dev/null || true
        ${config.virtualisation.docker.package}/bin/docker rm "$CONTAINER_NAME" 2>/dev/null || true
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  }) containercfg;

in
{
  options = {
    host.feature.virtualization.docker = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables tools and daemon for containerization";
      };
      bridge_loopback = mkOption {
        default = true;
        type = with types; bool;
        description = "Allow for NAT Loopback from br-* interfaces to allow resolving host";
      };
      containers = mkOption {
        default = {};
        type = types.attrsOf containerType;
        description = "Container definitions using advanced container system";
      };
    };
  };

  config = mkIf ((cfg.enable) || (containercfg != {})) {
    environment = {
      etc = {
        "docker/daemon.json" = {
          text = ''
            {
              "experimental": true,
              "live-restore": true,
              "shutdown-timeout": 120
            }
          '';
          mode = "0600";
        };
      };

      #systemPackages = with pkgs; [ unstable.docker-compose ];

      # Embedded compose-to-nix converter
      systemPackages = with pkgs; [
        unstable.docker-compose
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

    host = {
      service = {
        docker_container_manager.enable = true;
      };
    };

    networking.firewall.trustedInterfaces = mkIf (cfg.bridge_loopback) [
      "br-+"
    ];

    # SOPS secrets for containers that need them
    sops.secrets = mkMerge (mapAttrsToList (containerName: cfg:
      generateSOPSSecrets containerName cfg
    ) containercfg);

    programs = {
      bash = {
        interactiveShellInit = ''
          ### Docker

            if [ -n "$XDG_CONFIG_HOME" ] ; then
                export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
            else
                export DOCKER_CONFIG="$HOME/.config/docker"
            fi

            export DOCKER_TIMEOUT=''${DOCKER_TIMEOUT:-"120"}

            # Figure out if we need to use sudo for docker commands
            if id -nG "$USER" | grep -qw "docker" || [ $(id -u) = "0" ]; then
                dsudo=""
            else
                dsudo='sudo'
            fi

            alias dpsa="$dsudo docker_ps -a"                                               # Get process included stop container
            alias di="$dsudo ${config.virtualisation.docker.package}/bin/docker images"                                                # Get images
            alias dki="$dsudo ${config.virtualisation.docker.package}/bin/docker run -it -P"                                           # Run interactive container, e.g., $dki base /bin/bash
            alias dex="$dsudo ${config.virtualisation.docker.package}/bin/docker exec -it"                                             # Execute interactive container, e.g., $dex base /bin/bash
            dstop() { $dsudo ${config.virtualisation.docker.package}/bin/docker stop $($dsudo ${config.virtualisation.docker.package}/bin/docker ps -a -q) -t $DOCKER_TIMEOUT; }   # Stop all containers
            #drm() { $dsudo ${config.virtualisation.docker.package}/bin/docker rm $($dsudo ${config.virtualisation.docker.package}/bin/docker ps -a -q); }                                                                                    # Remove all containers
            #dri() { $dsudo ${config.virtualisation.docker.package}/bin/docker rmi -f $($dsudo ${config.virtualisation.docker.package}/bin/docker images -q); }                                                                               # Forcefully Remove all images
            #drmf() { $dsudo ${config.virtualisation.docker.package}/bin/docker stop $($dsudo ${config.virtualisation.docker.package}/bin/docker ps -a -q) -timeout $DOCKER_COMPOSE_TIMEOUT && $dsudo ${config.virtualisation.docker.package}/bin/docker rm $($dsudo ${config.virtualisation.docker.package}/bin/docker ps -a -q) ; } # Stop and remove all containers
            db() { $dsudo ${config.virtualisation.docker.package}/bin/docker build -t="$1" .; } # Build Docker Image from Current Directory

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
                ip=$($dsudo ${config.virtualisation.docker.package}/bin/docker inspect --format="{{.NetworkSettings.IPAddress}}" "$1" 2>/dev/null)
                if (($? >= 1)); then
                    # Container doesn't exist
                    ip='n/a'
                fi
                echo $ip
            }
            alias dip='docker_ip'

            # Enhanced version of 'docker ps' which outputs two extra columns IP and RAM
            docker_ps() {
                tmp=$($dsudo ${config.virtualisation.docker.package}/bin/docker ps "$@")
                headings=$(echo "$tmp" | head --lines=1)
                max_len=$(echo "$tmp" | wc --max-line-length)
                dps=$(echo "$tmp" | tail --lines=+2)
                printf "%-''${max_len}s %-15s %10s\n" "$headings" IP RAM

                if [[ -n "$dps" ]]; then
                    while read -r line; do
                        container_short_hash=$(echo "$line" | cut -d' ' -f1)
                        container_long_hash=$($dsudo ${config.virtualisation.docker.package}/bin/docker inspect --format="{{.Id}}" "$container_short_hash")
                        container_name=$(echo "$line" | rev | cut -d' ' -f1 | rev)
                        if [ -n "$container_long_hash" ]; then
                            ram=$(docker_mem "$container_long_hash")
                            ip=$(docker_ip "$container_name")
                            printf "%-''${max_len}s %-15s %10s\n" "$line" "$ip" "$ram"
                        fi
                    done <<<"$dps"
                fi

            }
            alias dps='docker_ps'

            #  List the volumes for a given container
            docker_vol() {
                vols=$($dsudo ${config.virtualisation.docker.package}/bin/docker inspect --format="{{.HostConfig.Binds}}" "$1")
                vols=''${vols:1:-1}
                for vol in $vols; do
                    echo "$vol"
                done
            }

            alias dvol='docker_vol'

            if command -v "fzf" &>/dev/null; then
                # bash into running container
                alias dbash='c_name=$($dsudo ${config.virtualisation.docker.package}/bin/docker ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed"/NAMES/d" | sort | fzf --tac |  ${pkgs.gawk}/bin/awk '"'"'{print $1;}'"'"') ; echo -e "\e[41m**\e[0m Entering $c_name from $(cat /etc/hostname)" ; $dsudo ${config.virtualisation.docker.package}/bin/docker exec -e COLUMNS=$( tput cols ) -e LINES=$( tput lines ) -it $c_name bash'

                # view logs
                alias dlog='c_name=$($dsudo ${config.virtualisation.docker.package}/bin/docker ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed"/NAMES/d" | sort | fzf --tac |  ${pkgs.gawk}/bin/awk '"'"'{print $1;}'"'"') ; echo -e "\e[41m**\e[0m Viewing $c_name from $(cat /etc/hostname)" ; $dsudo ${config.virtualisation.docker.package}/bin/docker logs $c_name $1'

                # sh into running container
                alias dsh='c_name=$($dsudo ${config.virtualisation.docker.package}/bin/docker ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed"/NAMES/d" | sort | fzf --tac |  ${pkgs.gawk}/bin/awk '"'"'{print $1;}'"'"') ; echo -e "\e[41m**\e[0m Entering $c_name from $(cat /etc/hostname)" ; $dsudo ${config.virtualisation.docker.package}/bin/docker exec -e COLUMNS=$( tput cols ) -e LINES=$( tput lines ) -it $c_name sh'

                # Remove running container
                alias drm='$dsudo ${config.virtualisation.docker.package}/bin/docker rm $( $dsudo ${config.virtualisation.docker.package}/bin/docker ps --format "table {{.Names}}\t{{.Image}}\t{{ .ID}}\t{{.RunningFor}}" | ${pkgs.gnused}/bin/sed"/NAMES/d" | sort | fzf --tac |  ${pkgs.gawk}/bin/awk '"'"'{print $1;}'"'"' )'
            fi

          ### Docker Compose
          export DOCKER_COMPOSE_TIMEOUT=''${DOCKER_COMPOSE_TIMEOUT:-"120"}
          docker_compose_location=$(which docker-compose)

          container_tool() {
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
                          $docker_compose_location -f "$stack_dir"/*compose.yml pull
                      else
                          echo "**** [container-tool] [pull] Skipping - $stack_dir"
                      fi
                  done
              }

              ct_pull_restart () {
                  for stack_dir in "$@" ; do
                      if [ ! -f "$stack_dir"/.norestart ]; then
                          echo "**** [container-tool] [pull_restart] Pulling Images - $stack_dir"
                          $docker_compose_location -f "$stack_dir"/*compose.yml pull
                          echo "**** [container-tool] [pull_restart] Bringing up stack - $stack_dir"
                          $docker_compose_location -f "$stack_dir"/*compose.yml up -d
                      else
                          echo "**** [container-tool] [pull_restart] Skipping - $stack_dir"
                      fi
                  done
              }

              ct_restart () {
                  for stack_dir in "$@" ; do
                      if [ ! -f "$stack_dir"/.norestart ]; then
                          echo "**** [container-tool] [restart] Bringing down stack - $stack_dir"
                          $docker_compose_location -f "$stack_dir"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
                          echo "**** [container-tool] [restart] Bringing up stack - $stack_dir"
                          $docker_compose_location -f "$stack_dir"/*compose.yml up -d
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
                          $docker_compose_location -f "$stack_dir"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
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
                  # the order to restart system containers:
                  predef_order=($(echo "$DOCKER_STACK_SYSTEM_APP_RESTART_ORDER"))

                  curr_order=()

                  for stack_dir in "$DOCKER_STACK_SYSTEM_DATA_PATH"/* ; do
                      curr_order=("''${curr_order[@]}" "''${stack_dir##*/}")
                  done

                  # pass the array by reference
                  ct_sort_order curr_order
                  ct_restart_service "''${curr_order[@]}"
              }

              ct_stop_stack () {
                  stacks=$($docker_compose_location ls | tail -n +2 |  ${pkgs.gawk}/bin/awk '{print $1}')
                  for stack in $stacks; do
                      stack_image=$($docker_compose_location -p $stack images | tail -n +2 |  ${pkgs.gawk}/bin/awk '{print $1,$2}' | grep "db-backup")
                          if [ "$1" != "nobackup" ] ; then
                              if [[ $stack_image =~ .*"db-backup".* ]] ; then
                                  stack_container_name=$(echo "$stack_image" |  ${pkgs.gawk}/bin/awk '{print $1}')
                                  echo "** Backing up database for '$stack_container_name' before stopping"
                                  ${config.virtualisation.docker.package}/bin/docker exec $stack_container_name /usr/local/bin/backup-now
                              fi
                          fi
                      echo "** Gracefully stopping compose stack: $stack"
                      $docker_compose_location -p $stack down --timeout $DOCKER_COMPOSE_TIMEOUT
                  done
              }

              ct_stop_sys_containers () {
                  # the order to restart system containers:
                  #predef_order=(tinc openldap unbound traefik error-pages postfix-relay llng-handler clamav zabbix fluent-bit)
                  predef_order=($(echo "$DOCKER_STACK_SYSTEM_APP_RESTART_ORDER"))

                  curr_order=()

                  for stack_dir in "$DOCKER_STACK_SYSTEM_DATA_PATH"/* ; do
                          curr_order=("''${curr_order[@]}" "''${stack_dir##*/}")
                  done

                  # pass the array by reference
                  ct_sort_order curr_order
                  ct_stop_service "''${curr_order[@]}"
              }

              ct_pull_restart_containers () {
                  ## System containers have been moved to systemd
                  # the order to restart system containers:
                  #predef_order=($(echo "$DOCKER_STACK_SYSTEM_APP_RESTART_ORDER"))

                  #curr_order=()

                  #for stack_dir in "$DOCKER_STACK_SYSTEM_DATA_PATH"/*/ ; do
                  #    if [ -s "$stack_dir"/*compose.yml ]; then
                  #        curr_order=("''${curr_order[@]}" "''${stack_dir##*/}")
                  #    fi
                  #done

                  # pass the array by reference
                  #ct_sort_order curr_order

                  #echo "''${curr_order[@]}"
                  #if [ "$1" = restart ] ; then
                  #    ct_pull_restart "''${curr_order[@]}"
                  #else
                  #    ct_pull_images "''${curr_order[@]}"
                  #fi

                  # there is no particular order to retart application containers
                  # except the DOCKER_COMPOSE_STACK_APP_RESTART_FIRST, which should be restarted as the
                  # first container, even before system containers
                  curr_order=()

                  for stack_dir in "$DOCKER_COMPOSE_STACK_DATA_PATH"/*/ ; do
                      if [ "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST" != "$stack_dir" ] && [ -s "$stack_dir"/*compose.yml ]; then
                          curr_order=("''${curr_order[@]}" "$stack_dir")
                      fi
                  done

                  # no need to sort order
                  if [ "$1" = restart ] ; then
                      ct_pull_restart "''${curr_order[@]}"
                  else
                      ct_pull_images "''${curr_order[@]}"
                  fi
              }

              ct_restart_app_containers () {
                  # there is no particular order to retart application containers
                  # except the DOCKER_COMPOSE_STACK_APP_RESTART_FIRST, which should be restarted as the
                  # first container, even before system containers
                  curr_order=()

                  for stack_dir in "$DOCKER_COMPOSE_STACK_DATA_PATH"/*/ ; do
                      if [ "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST" != "$stack_dir" ] && [ -s "$stack_dir"/*compose.yml ]; then
                          curr_order=("''${curr_order[@]}" "$stack_dir")
                      fi
                  done

                  # no need to sort order
                  ct_restart "''${curr_order[@]}"
              }

              ct_stop_app_containers () {
                  # there is no particular order to retart application containers
                  # except the DOCKER_COMPOSE_STACK_APP_RESTART_FIRST, which should be restarted as the
                  # first container, even before system containers
                  curr_order=()

                  for stack_dir in "$DOCKER_COMPOSE_STACK_DATA_PATH"/*/ ; do
                      if [ "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST" != "$stack_dir" ] && [ -s "$stack_dir"/*compose.yml ]; then
                          curr_order=("''${curr_order[@]}" "$stack_dir")
                      fi
                  done

                  # no need to sort order
                  ct_stop "''${curr_order[@]}"
              }

              ct_restart_first () {
                  if [ -s "$DOCKER_COMPOSE_STACK_DATA_PATH""$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml ]; then
                        echo "**** [container-tool] [restart_first] Bringing down stack - $DOCKER_COMPOSE_STACK_DATA_PATH$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"
                        $docker_compose_location -f "$DOCKER_COMPOSE_STACK_DATA_PATH"/"$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml down --timeout $DOCKER_COMPOSE_TIMEOUT
                        echo "**** [container-tool] [restart_first] Bringing up stack - $DOCKER_COMPOSE_STACK_DATA_PATH$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"
                        $docker_compose_location -f "$DOCKER_COMPOSE_STACK_DATA_PATH"/"$DOCKER_COMPOSE_STACK_APP_RESTART_FIRST"/*compose.yml up -d
                  fi
              }

              if [ "$#" -gt 2 ] || { [ "$#" -eq 2 ] && [ "$2" != "--debug" ]; } then
                  echo $"Usage:"
                  echo "  $0 {core|applications|apps|pull|--all}"
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
                  --all|-a)  # restart all containers
                      echo "**** [container-tool] Restarting all Containers"
                      ct_restart_first
                      ct_restart_sys_containers
                      ct_restart_app_containers
                      if pgrep -x "sssd" >/dev/null ; then
                          echo "**** [container-tool] Restarting SSSD"
                          systemctl restart sssd
                      fi
                  ;;
                  pull) # Pull new images
                      if [ "$2" = "restart" ] ; then pull_str="and restarting containers" ; fi
                      echo "**** [container-tool] Pulling all images $pull_str for compose.yml files (!= .norestart)"
                      ct_pull_restart_containers $2
                  ;;
                  shutdown) # stop all containers via compose stack
                      if [ "$2" = "nobackup" ] ; then shutdown_str="NOT" ; fi
                      echo "**** [container-tool] Stopping all compose stacks and $shutdown_str backing up databases if a db-backup container exists"
                      ct_stop_stack
                  ;;
                  stop) # stop all containers
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
          }

          docker-compose() {
             if [ "$2" != "--help" ] ; then
                 case "$1" in
                     "down" )
                         arg=$(echo "$@" | ${pkgs.gnused}/bin/sed"s|^$1||g")
                         $dsudo $docker_compose_location down --timeout $DOCKER_COMPOSE_TIMEOUT $arg
                     ;;
                     "restart" )
                         arg=$(echo "$@" | ${pkgs.gnused}/bin/sed"s|^$1||g")
                         $dsudo $docker_compose_location restart --timeout $DOCKER_COMPOSE_TIMEOUT $arg
                     ;;
                     "stop" )
                         arg=$(echo "$@" | ${pkgs.gnused}/bin/sed"s|^$1||g")
                         $dsudo $docker_compose_location stop --timeout $DOCKER_COMPOSE_TIMEOUT $arg
                     ;;
                     "up" )
                         arg=$(echo "$@" | ${pkgs.gnused}/bin/sed"s|^$1||g")
                         $dsudo $docker_compose_location up $arg
                     ;;
                     * )
                         $dsudo $docker_compose_location ''${@}
                     ;;
                esac
             fi
          }

          alias container-tool=container_tool
          alias dpull='$dsudo ${config.virtualisation.docker.package}/bin/docker pull'                                                                                                 # ${config.virtualisation.docker.package}/bin/docker Pull
          alias dcpull='$dsudo docker-compose pull'                                                                                        # Docker-Compose Pull
          alias dcu='$dsudo $docker_compose_location up'                                                                                   # Docker-Compose Up
          alias dcud='$dsudo $docker_compose_location up -d'                                                                               # Docker-Compose Daemonize
          alias dcd='$dsudo $docker_compose_location down --timeout $DOCKER_COMPOSE_TIMEOUT'                                               # Docker-Compose Down
          alias dcl='$dsudo $docker_compose_location logs -f'                                                                              # ${config.virtualisation.docker.package}/bin/docker Compose Logs
          alias dcrecycle='$dsudo $docker_compose_location down --timeout $DOCKER_COMPOSE_TIMEOUT ; $dsudo $docker_compose_location up -d' # ${config.virtualisation.docker.package}/bin/docker Compose Restart

          if [ -n "$1" ] && [ "$1" = "container_tool" ] ; then
              arg=$(echo "$@" | ${pkgs.gnused}/bin/sed"s|^$1||g")
              container_tool $arg
          fi
          '';
      };
    };

    system.activationScripts.create_docker_networks = ''
        if [ -d /var/local/data ]; then
          mkdir -p /var/local/data
        fi

        if [ -d /var/local/data/_system ] ; then
          mkdir -p /var/local/data/_system
        fi

        if [ -d /var/local/db ]; then
          mkdir -p /var/local/db
          ${pkgs.e2fsprogs}/bin/chattr +C /var/local/db
        fi

        if ${pkgs.procps}/bin/pgrep dockerd > /dev/null 2>&1 ; then
          ${config.virtualisation.docker.package}/bin/docker network inspect proxy > /dev/null || ${config.virtualisation.docker.package}/bin/docker network create proxy --subnet 172.19.0.0/18
          ${config.virtualisation.docker.package}/bin/docker network inspect proxy-internal > /dev/null || ${config.virtualisation.docker.package}/bin/docker network create proxy-internal --subnet 172.19.64.0/18
          ${config.virtualisation.docker.package}/bin/docker network inspect services >/dev/null || ${config.virtualisation.docker.package}/bin/docker network create services --subnet 172.19.128.0/18
          ${config.virtualisation.docker.package}/bin/docker network inspect socket-proxy >/dev/null || ${config.virtualisation.docker.package}/bin/docker network create socket-proxy --subnet 172.19.192.0/18
        fi
      '';

    users.groups = { docker = { }; };

    virtualisation = {
      docker = {
        enable = mkDefault true;
        enableOnBoot = mkDefault false;
        logDriver = mkDefault "local";
        storageDriver = docker_storage_driver;
      };

      oci-containers.backend = mkDefault "docker";
    };

    systemd.services = mkMerge [
      # Apply special port services for containers with special ports
      (mkMerge (mapAttrsToList (containerName: cfg:
        optionalAttrs (cfg.enable or false && (any (port: port.enable) (cfg.ports or []))) {
          "docker-${containerName}" = containerConfigs.${containerName}.specialPortsService;
        }
      ) containercfg))

      # Apply standard containers as custom systemd services
      (mkMerge (mapAttrsToList (containerName: cfg:
        optionalAttrs (cfg.enable or false && !(any (port: port.enable) (cfg.ports or []))) {
          "docker-${containerName}" = mkService containerName cfg;
        }
      ) containercfg))
    ];
  };
}

