{ config, inputs, lib, modulesPath, pkgs, ...}:
let
  role = config.host.role;
in
  with lib;
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  config = mkIf (role == "vm") {
    documentation = {                                 # This makes some nix commands not display --help
      enable = mkDefault false;
      info.enable = mkDefault false;
      man.enable = mkDefault false;
      nixos.enable = mkDefault false;
    };

    host = {
      feature = {
        boot = {
          efi.enable = mkDefault true;
          graphical.enable = mkDefault false;
        };
        graphics = {
          enable = mkDefault false;                   # Maybe if we were doing openCL
        };
        powermanagement = {
          battery.enable = mkDefault false;
          disks = {
            enable = mkDefault false;
            platter = mkDefault false;
          };
          powertop = {
            enable = mkDefault false;
            startup = mkDefault false;
          };
          thermal.enable = mkDefault false;
          tlp.enable = mkDefault fasle;
          undervolt.enable = mkDefault false;
        };
      };
      filesystem = {
        btrfs.enable = mkDefault true;
        encryption.enable = mkDefault false;
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
        printing.enable = mkDefault false;
        raid.enable = mkDefault false;
        scanning.enable = mkDefault false;
        sound.enable = mkDefault true;
        webcam.enable = mkDefault false;
        wireless.enable = mkDefault false;
        yubikey.enable = mkDefault false;
      };
      network = {
        manager = mkDefault "networkmanager";
        firewall.fail2ban.enable = mkDefault false;
      };
      service = {
        logrotate.enable = mkDefault true;
        ssh = {
          enable = mkDefault true;
          harden = mkDefault true;
        };
      };
    };

    services.qemuGuest.enable = mkDefault true;        # Make the assumption we're using QEMU

    systemd = {
      enableEmergencyMode = mkDefault false;           # Allow system to continue booting in headless mode.
      sleep.extraConfig = ''
        AllowSuspend=no
        AllowHibernation=no
      '';
    };
  };
}
