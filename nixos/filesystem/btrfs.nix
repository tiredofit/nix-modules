{config, lib, pkgs, ...}:

let
  cfg = config.host.filesystem.btrfs;
in
  with lib;
{
  options = {
    host.filesystem.btrfs = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables settings for a BTRFS installation including snapshots";
      };
      autoscrub = mkOption {
       default = true;
        type = with types; bool;
        description = "Enable autoscrubbing of file systems";
      };
      snapshot = mkOption {
        default = true;
        type = with types; bool;
        description = "Enable automatic configuration of snapshotting of certain subvolumes";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      supportedFilesystems = [
        "btrfs"
      ];
    };

    fileSystems = {
      "/".options = [ "subvol=root" "compress=zstd" "noatime"  ];
      "/home".options = [ "subvol=home/active" "compress=zstd" "noatime"  ];
      "/home/.snapshots".options = [ "subvol=home/snapshots" "compress=zstd" "noatime"  ];
      "/nix".options = [ "subvol=nix" "compress=zstd" "noatime"  ];
      "/var/lib/docker".options = [ "subvol=var_lib_docker" "compress=zstd" "noatime"  ];
      "/var/local".options = [ "subvol=var_local/active" "compress=zstd" "noatime"  ];
      "/var/local/.snapshots".options = [ "subvol=var_local/snapshots" "compress=zstd" "noatime"  ];
      "/var/log".options = [ "subvol=var_log" "compress=zstd" "noatime" "nodatacow"  ];
      "/var/log".neededForBoot = true;
    };

    services = {
      btrbk = mkIf cfg.snapshot {
        instances."btrbak" = {
          onCalendar = mkDefault "*-*-* *:00:00";
          settings = {
            timestamp_format = mkDefault "long";
            preserve_day_of_week = mkDefault "sunday" ;
            preserve_hour_of_day = mkDefault "0" ;
            snapshot_preserve = mkDefault "48h 10d 4w 12m 10y" ;
            snapshot_preserve_min = mkDefault "2d";
            volume."/home" = {
              snapshot_create = mkDefault "always";
              subvolume = mkDefault ".";
              snapshot_dir = mkDefault ".snapshots";
            };
            volume."/var/local" = {
              snapshot_create = mkDefault "always";
              subvolume = mkDefault ".";
              snapshot_dir = mkDefault ".snapshots";
            };
          };
        };
      };
      btrfs.autoScrub = mkIf cfg.autoscrub {
        enable = true;
        fileSystems = ["/"];
      };
    };
  };
}
