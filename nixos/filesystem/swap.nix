 {config, lib, pkgs, ...}:

let
  cfg = config.host.filesystem.swap;
  # Do not compute a device path by concatenation at top-level because
  # cfg.partition may be null during evaluation. Compute per-case below.
in
  with lib;
{
  options = {
    host.filesystem.swap = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Swap";
      };
      type = mkOption {
        default = null;
        type = with types; nullOr (types.enum [ "file" "partition" ]);
        description = "Swap Type";
      };
      encrypt = mkOption {
        default = true;
        type = with types; bool;
        description = "Perform random encryption";
      };
      file = mkOption {
        default = "/swap/swapfile";
        type = with types; str;
        description = "Location of Swapfile";
      };
      partition = mkOption {
        default = null;
        type = with types; nullOr types.str;
        example = "sda2";
        description = "Partition to be used for swap";
      };
      size= mkOption {
        type = with types; int;
        default = 8192;
        description = "Size in Megabytes";
      };
    };
  };

  config = mkMerge [
    # Don't use BTRFS subvolume if RAID is involved.
    (mkIf ((cfg.enable) && (!config.host.hardware.raid.enable) && (cfg.type == "file")) {
      fileSystems = mkIf (config.host.filesystem.btrfs.enable) {
        "/swap".options = [ "subvol=swap" "nodatacow" "noatime" ];
      };

      swapDevices = [{
        device = swap_location;
        randomEncryption = {
          enable = cfg.encrypt;
          allowDiscards = "once";
        };
        size = cfg.size;
      }];
    })

    # Partition-backed swap: only create a swapDevices entry if partition is set
    (mkIf ((cfg.enable) && (cfg.type == "partition") && (cfg.partition != null)) {
      swapDevices = [{
        device = "/dev/" + cfg.partition;
        randomEncryption.enable = false;
      }];
    })

  {
    systemd.services = mkIf ((cfg.type == "file") && (!config.host.hardware.raid.enable) && (cfg.enable)) {
      create-swapfile =  {
        serviceConfig.Type = "oneshot";
        wantedBy = [ "swap-swapfile.swap" ];
        script = ''
          swapfile="${cfg.file}"
          if [ -f "$swapfile" ]; then
              echo "Swap file $swapfile already exists, taking no action"
          else
              echo "Setting up swap file $swapfile"
              ${pkgs.coreutils}/bin/truncate -s 0 "$swapfile"
              ${pkgs.e2fsprogs}/bin/chattr +C "$swapfile"
              ${pkgs.btrfs-progs}/bin/btrfs property set "$swapfile" compression none
              ${pkgs.coreutils}/bin/dd if=/dev/zero of="$swapfile" bs=1M count=${toString cfg.size} status=progress
              ${pkgs.coreutils}/bin/chmod 0600 "$swapfile"
              ${pkgs.util-linux}/bin/mkswap "$swapfile"
          fi
        '';
      };
    };
  }];
}
