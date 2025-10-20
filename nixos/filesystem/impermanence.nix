{config, inputs, lib, outputs, pkgs, ...}:

let
  cfg_impermanence = config.host.filesystem.impermanence;
  cfg_encrypt = config.host.filesystem.encryption;
in
  with lib;
{
  imports =
  [
    inputs.impermanence.nixosModules.impermanence
  ];

  options = {
    host.filesystem.impermanence = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Wipe root filesystem and restore blank root BTRFS subvolume on boot. Also known as 'Erasing your darlings'";
      };
      root-subvol = mkOption {
          type = types.str;
          default = "root";
          description = "Root subvolume to wipe on boot";
      };
      blank-root-subvol = mkOption {
        type = types.str;
        default = "root-blank";
        description = "Blank root subvolume to restore on boot";
      };
      directories = mkOption {
        type = types.listOf types.anything;
        default = [];
        description = "Directories that should be persisted between reboots";
      };
      files = mkOption {
        type = types.listOf types.anything;
        default = [];
        description = "Files that should be persisted between reboots";
      };
      persist = {
        machine-id = mkOption {
          type = types.bool;
          default = false;
          description = "Persist /etc/machine-id across reboots.";
        };
      };
    };
  };

  config = lib.mkMerge [
  {
    boot.initrd = lib.mkMerge [
      (lib.mkIf ((cfg_impermanence.enable) && (!cfg_encrypt.enable) && (config.host.filesystem.btrfs.enable)) {
        postDeviceCommands = pkgs.lib.mkBefore ''
          mkdir -p /mnt
          set -x
          # Find a btrfs device that contains the configured root subvolume.
          # Prefer blkid-discovered btrfs devices for faster and more accurate filtering.
          find_btrfs_device() {
            root_subvol='${cfg_impermanence.root-subvol}'

            # iterate blkid results without using a pipe/while (avoid subshells so return works)
            for d in $(blkid -o device -t TYPE=btrfs 2>/dev/null); do
              [ -e "$d" ] || continue
              echo "[impermanence] checking $d" >&2
              _tmp=$(mktemp -d) || continue
              if mount -o ro "$d" "$_tmp" 2>/dev/null; then
                if btrfs subvolume list "$_tmp" 2>/dev/null | awk '{print $9}' | grep -qx "$root_subvol"; then
                  umount "$_tmp" 2>/dev/null || true
                  rmdir "$_tmp" 2>/dev/null || true
                  echo "$d"
                  return 0
                fi
                umount "$_tmp" 2>/dev/null || true
              fi
              rmdir "$_tmp" 2>/dev/null || true
            done

            return 1
          }

          btrfs_root_device=$(find_btrfs_device)
          find_rc=$?
          if [ $find_rc -ne 0 ] || [ -z "$btrfs_root_device" ]; then
            echo "[impermanence] Could not find btrfs device containing subvolume ${cfg_impermanence.root-subvol}" >&2
            exit 1
          fi

          echo "[impermanence] using $btrfs_root_device" >&2
          mount -o subvol=/ "$btrfs_root_device" /mnt
          btrfs subvolume list -o /mnt/${cfg_impermanence.root-subvol} | cut -f9 -d' ' |
          while read subvolume; do
              echo "Deleting /$subvolume subvolume"
              btrfs subvolume delete "/mnt/$subvolume"
          done &&
          echo "Deleting /${cfg_impermanence.root-subvol} subvolume" &&
          btrfs subvolume delete /mnt/${cfg_impermanence.root-subvol}
          echo "Restoring blank /${cfg_impermanence.root-subvol} subvolume"
          btrfs subvolume snapshot /mnt/${cfg_impermanence.blank-root-subvol} /mnt/${cfg_impermanence.root-subvol}
          mkdir -p /mnt/${cfg_impermanence.root-subvol}/mnt
          umount /mnt
          set +x
        '';
      })

      (lib.mkIf ((cfg_impermanence.enable) && (cfg_encrypt.enable) && (config.host.filesystem.btrfs.enable)) {
        systemd = {
          enable = true;
          services.rollback = {
            description = "Rollback BTRFS root subvolume to a pristine state";
            wantedBy = [
              "initrd.target"
            ];
            after = [
              "systemd-cryptsetup@${cfg_encrypt.encrypted-partition}.service"
            ];
            before = [
              "sysroot.mount"
            ];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = ''
              mkdir -p /mnt
              # If encrypted, prefer blkid-discovered btrfs devices and the specified mapper device.
              find_btrfs_device() {
                root_subvol='${cfg_impermanence.root-subvol}'
                mapper=/dev/mapper/${cfg_encrypt.encrypted-partition}

                if [ -e "$mapper" ]; then
                  echo "[impermanence] checking mapper $mapper" >&2
                  _tmp=$(mktemp -d) || true
                  if [ -n "$_tmp" ] && mount -o ro "$mapper" "$_tmp" 2>/dev/null; then
                    if btrfs subvolume list "$_tmp" 2>/dev/null | awk '{print $9}' | grep -qx "$root_subvol"; then
                      umount "$_tmp" 2>/dev/null || true
                      rmdir "$_tmp" 2>/dev/null || true
                      echo "$mapper" && return 0
                    fi
                    umount "$_tmp" 2>/dev/null || true
                  fi
                  rmdir "$_tmp" 2>/dev/null || true
                fi

                # Use blkid first to limit candidates
                blkid -o device -t TYPE=btrfs 2>/dev/null | while read d; do
                  [ -e "$d" ] || continue
                  echo "[impermanence] checking $d" >&2
                  _tmp=$(mktemp -d) || continue
                  if mount -o ro "$d" "$_tmp" 2>/dev/null; then
                    if btrfs subvolume list "$_tmp" 2>/dev/null | awk '{print $9}' | grep -qx "$root_subvol"; then
                      umount "$_tmp" 2>/dev/null || true
                      rmdir "$_tmp" 2>/dev/null || true
                      echo "$d" && return 0
                    fi
                    umount "$_tmp" 2>/dev/null || true
                  fi
                  rmdir "$_tmp" 2>/dev/null || true
                done

                for dev in $(ls /dev/mapper 2>/dev/null | sed 's/^/\/dev\/mapper\//'); do
                  [ -e "$dev" ] || continue
                  echo "[impermanence] checking $dev" >&2
                  _tmp=$(mktemp -d) || continue
                  if mount -o ro "$dev" "$_tmp" 2>/dev/null; then
                    if btrfs subvolume list "$_tmp" 2>/dev/null | awk '{print $9}' | grep -qx "$root_subvol"; then
                      umount "$_tmp" 2>/dev/null || true
                      rmdir "$_tmp" 2>/dev/null || true
                      echo "$dev" && return 0
                    fi
                    umount "$_tmp" 2>/dev/null || true
                  fi
                  rmdir "$_tmp" 2>/dev/null || true
                done

                for dev in /dev/*[0-9] /dev/nvme*n*p* /dev/sd*; do
                  [ -e "$dev" ] || continue
                  echo "[impermanence] checking $dev" >&2
                  _tmp=$(mktemp -d) || continue
                  if mount -o ro "$dev" "$_tmp" 2>/dev/null; then
                    if btrfs subvolume list "$_tmp" 2>/dev/null | awk '{print $9}' | grep -qx "$root_subvol"; then
                      umount "$_tmp" 2>/dev/null || true
                      rmdir "$_tmp" 2>/dev/null || true
                      echo "$dev" && return 0
                    fi
                    umount "$_tmp" 2>/dev/null || true
                  fi
                  rmdir "$_tmp" 2>/dev/null || true
                done

                return 1
              }

              BTRFS_DEV=$(find_btrfs_device)
              find_rc=$?
              if [ $find_rc -ne 0 ] || [ -z "$BTRFS_DEV" ]; then
                echo "[impermanence] Could not find btrfs device containing subvolume ${cfg_impermanence.root-subvol}" >&2
                exit 1
              fi

              echo "[impermanence] using $BTRFS_DEV" >&2
              mount -o subvol=/ "$BTRFS_DEV" /mnt
              btrfs subvolume list -o /mnt/${cfg_impermanence.root-subvol} | cut -f9 -d' ' |
              while read subvolume; do
                echo "Deleting /$subvolume subvolume"
                btrfs subvolume delete "/mnt/$subvolume"
              done &&
              echo "Deleting /${cfg_impermanence.root-subvol} subvolume" &&
              btrfs subvolume delete /mnt/${cfg_impermanence.root-subvol}
              echo "Restoring blank /${cfg_impermanence.root-subvol} subvolume"
              btrfs subvolume snapshot /mnt/${cfg_impermanence.blank-root-subvol} /mnt/${cfg_impermanence.root-subvol}
              mkdir -p /mnt/${cfg_impermanence.root-subvol}/mnt
              umount /mnt
            '';
          };
        };
      })
    ];

    environment = mkIf ((cfg_impermanence.enable) && (config.host.filesystem.btrfs.enable)) {
      systemPackages =
        let
          # Running this will show what changed during boot to potentially use for persisting
          impermanence-fsdiff = pkgs.writeShellScriptBin "impermanence-fsdiff" ''
            _mount_drive=''${1:-"$(mount | grep '.* on / type btrfs' | awk '{ print $1}')"}
            _tmp_root=$(mktemp -d)
            mkdir -p "$_tmp_root"
            sudo mount -o subvol=/ "$_mount_drive" "$_tmp_root" > /dev/null 2>&1

            set -euo pipefail

            OLD_TRANSID=$(sudo btrfs subvolume find-new $_tmp_root/root-blank 9999999)
            OLD_TRANSID=''${OLD_TRANSID#transid marker was }

            sudo btrfs subvolume find-new "$_tmp_root/${cfg_impermanence.root-subvol}" "$OLD_TRANSID" | sed '$d' | cut -f17- -d' ' | sort | uniq |
            while read path; do
              path="/$path"
               if [ -L "$path" ]; then
                  : # The path is a symbolic link, so is probably handled by NixOS already
                elif [ -d "$path" ]; then
                  : # The path is a directory, ignore
                else
                  echo "$path"
                fi
              done
              sudo umount "$_tmp_root"
              rm -rf "$_tmp_root"
            '';
        in
          with pkgs; [
            impermanence-fsdiff
          ];

        persistence."/persist" = {
          hideMounts = true ;
          directories = [
            "/root"                            # Root
            "/var/lib/nixos"                   # Persist UID and GID mappings
          ]  ++ cfg_impermanence.directories;
          files = [
          ] ++ cfg_impermanence.files
            ++ lib.optional cfg_impermanence.persist.machine-id "/etc/machine-id";
        };
    };

    fileSystems = mkIf ((cfg_impermanence.enable) && (config.host.filesystem.btrfs.enable)) {
      "/persist" = {
        options = [ "subvol=persist/active" "compress=zstd" "noatime"  ];
        neededForBoot = true;
      };
      "/persist/.snapshots" = {
        options = [ "subvol=persist/snapshots" "compress=zstd" "noatime"  ];
      };
    };

    services = mkIf ((cfg_impermanence.enable) && (config.host.filesystem.btrfs.enable) && (config.host.filesystem.btrfs.snapshot)) {
      btrbk = {
        instances."btrbak" = {
          settings = {
            volume."/persist" = {
              snapshot_create = mkDefault "always";
              subvolume = mkDefault ".";
              snapshot_dir = mkDefault ".snapshots";
            };
          };
        };
      };
    };

    security = mkIf cfg_impermanence.enable {
      sudo.extraConfig = ''
        Defaults lecture = never
      '';
    };
  }];
}
