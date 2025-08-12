{ config, lib, pkgs, ... }:

with lib;
let

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
        aliases = {
          default = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to add the default network alias of ${hostname}-${name}.";
          };
          extra = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional network aliases for the container (in addition to the default).";
          };
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
            readOnly = mkOption {
              type = types.bool;
              default = false;
              description = "Mount as read-only";
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

      login = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            registry = mkOption {
              type = types.str;
              description = "Registry host";
            };
            username = mkOption {
              type = types.str;
              description = "Registry username";
            };
            passwordFile = mkOption {
              type = types.path;
              description = "Path to file containing registry password";
            };
          };
        });
        default = null;
        description = "Registry login credentials for this container";
      };

      containerName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom name for the container (defaults to attribute name if null)";
      };
    };
  });

  containercfg = config.host.feature.virtualization.docker.containers;
  proxy_env = config.networking.proxy.envVars;
  hostname = config.host.network.hostname;

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
      baseMount = "${vol.source}:${vol.target}";
      mountOptions =
        if vol.options != "" then vol.options
        else if vol.readOnly then "ro"
        else "";
      fullMountString = if mountOptions != "" then "${baseMount}:${mountOptions}" else baseMount;
    in
    "--volume ${fullMountString}"
  ) cfg.volumes;

  # Generate port arguments
  generatePortArgs = cfg: ''
    PORT_ARGS=""
    ${concatMapStringsSep "\n    " (portCfg: ''
      if [ "${if portCfg.enable then "true" else "false"}" = "true" ]; then
        echo "Processing port ${portCfg.host} with enable=${if portCfg.enable then "true" else "false"}"
        case "${portCfg.host}" in
          "80")
            IP="$BINDING_IP_80"
            #echo "Port 80: Using IP from BINDING_IP_80: $IP"
            ;;
          "443")
            IP="$BINDING_IP_443"
            #echo "Port 443: Using IP from BINDING_IP_443: $IP"
            ;;
          *)
            eval "IP=\$BINDING_IP_${portCfg.host}"
            #echo "Port ${portCfg.host}: Using eval, IP: $IP"
            ;;
        esac
        if [ -n "$IP" ]; then
          PORT_ARGS="$PORT_ARGS -p $IP:${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
          #echo "Added port binding: $IP:${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
        else
          PORT_ARGS="$PORT_ARGS -p ${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
          #echo "Using default binding for port ${portCfg.host} (no IP found)"
        fi
      else
        PORT_ARGS="$PORT_ARGS -p ${portCfg.host}:${portCfg.container}/${portCfg.protocol}"
        #echo "Port ${portCfg.host} not enabled, using default binding"
      fi
    '') cfg.ports}
  '';

  # Generate label arguments
  generateLabelArgs = cfg: concatMapStringsSep " " (labelArg: labelArg)
    (mapAttrsToList (k: v:
      let
        val =
          if builtins.isBool v then
            if v then "true" else "false"
          else if builtins.isInt v then
            toString v
          else
            v;
      in
      "--label='${k}=${val}'"
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

  # Helper function to create systemd service for containers
  mkService = name: container: let
    mkAfter = map (x: "docker-${x}.service") (container.serviceOrder.after or []);

    # Generate environment files (including SOPS secrets)
    allEnvironmentFiles = (generateEnvironmentFiles name container) ++ (container.environmentFiles or []);

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
        ++ (if !(elem "host" container.networking.networks)
            then (
              (if container.networking.aliases.default or false
                then [ "--network-alias=${hostname}-${name}" ]
                else [])
              ++ (map (alias: "--network-alias=${alias}") (container.networking.aliases.extra or []))
            )
            else []);

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

        ${lib.optionalString (
          container.login != null &&
          container.login.username != null &&
          container.login.passwordFile != null &&
          container.login.registry != null
        ) ''
          ${pkgs.coreutils}/bin/cat ${container.login.passwordFile} | ${config.virtualisation.docker.package}/bin/docker login ${container.login.registry} --username ${container.login.username} --password-stdin
        ''}
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
          ${optionalString (!(elem "host" cfg.networking.networks) && (cfg.networking.aliases.default or false)) "--network-alias=${hostname}-${containerName}"} \
          ${concatMapStringsSep " " (alias: "--network-alias=${alias}") (cfg.networking.aliases.extra or [])} \
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
    host.feature.virtualization.docker.containers = mkOption {
      default = {};
      type = types.attrsOf containerType;
      description = "Container definitions using advanced container system";
    };
  };

  config = mkIf ((config.host.feature.virtualization.docker.enable) && (containercfg != {})) {
    # SOPS secrets for containers that need them
    sops.secrets = mkMerge (mapAttrsToList (containerName: cfg:
      generateSOPSSecrets containerName cfg
    ) containercfg);


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
