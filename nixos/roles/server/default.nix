{ config, lib, modulesPath, options, pkgs, ... }:
let
  role = config.host.role;
in
  with lib;
{

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  config = mkIf (role == "server") {
    boot = {
      initrd = mkDefault {
        checkJournalingFS = false;                      # Get the server up as fast as possible
      };

      kernel.sysctl =  mkDefault {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";    # use TCP BBR has significantly increased throughput and reduced latency for connections
      };
    };

    environment.variables.BROWSER = "echo";           # Print the URL instead on servers

    fonts.fontconfig.enable = mkDefault false;        # No GUI

    host = {
      feature = {
        boot = {
          efi.enable = mkDefault true;
          graphical.enable = mkDefault false;
        };
        documentation = {
          enable = mkDefault true;
          man = {
            enable = mkDefault false;
          };
        };
        graphics = {
          enable = mkDefault false;                   # Maybe if we were doing openCL
        };
        powermanagement = {
          cpu = {
            enable = mkDefault false;
          };
          disks = {
            enable = mkDefault true;
            platter = mkDefault false;
          };
          thermal.enable = mkForce false;
          undervolt.enable = mkForce false;
        };
        virtualization = {
          docker = {
            enable = mkDefault true;
          };
        };
      };
      filesystem = {
        btrfs.enable = mkDefault true;
        encryption.enable = mkDefault true;
        impermanence = {
          enable = mkDefault true;
          directories = [

          ];
        };
        swap = {
          enable = mkDefault true;
          type = mkDefault "partition";
        };
      };
      hardware = {
        bluetooth.enable = mkDefault false;
        printing.enable = mkDefault false;            # My use case never involves a print server
        raid.enable = mkDefault false;
        scanning.enable = mkDefault false;
        sound.enable = mkDefault false;
        webcam.enable = mkDefault false;
        wireless.enable = mkDefault false;            # Most servers are ethernet?
        yubikey.enable = mkDefault false;
      };
      network = {
        firewall.fail2ban.enable = mkDefault true;
        manager = mkDefault "systemd-networkd";
      };
      service = {
        logrotate.enable = mkDefault true;
        ssh = {
          enable = mkDefault true;
          harden = mkDefault true;
        };
      };
    };

    networking = {
      dhcpcd.enable = mkDefault false;                # Let's stay static
      enableIPv6 = mkDefault false;                   # See you in 2040
      firewall = {
        enable = mkDefault true;                      # Make sure firewall is enabled
        allowPing = mkDefault true;
        rejectPackets = mkDefault false;
        logRefusedPackets = mkDefault false;
        logRefusedConnections = mkDefault true;
      };
      useDHCP = mkDefault false;
      #useNetworkd = mkDefault false;
    };

    systemd = {
      enableEmergencyMode = mkDefault false;        # Allow system to continue booting in headless mode.

      sleep.extraConfig = ''
        AllowSuspend=no
        AllowHibernation=no
      '';
      settings.Manager = {                        # See https://0pointer.de/blog/projects/watchdog.html
        RuntimeWatchdogSec = mkDefault "20s";     # Hardware watchdog reboot after 20s
        RebootWatchdogSec = mkDefault "30s";      # Force reboot when hangs after 30s. See https://utcc.utoronto.ca/~cks/space/blog/linux/SystemdShutdownWatchdog
        KExecWatchdogSec = mkDefault "1m";
      };
    };
  };
}
