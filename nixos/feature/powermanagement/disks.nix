{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.powermanagement.disks;
in
  with lib;
{
  options = {
    host.feature.powermanagement.disks = {
      enable = mkOption {
        default = true;
        type = with types; bool;
        description = "Enables adding disk power managemnet tools";
      };
      platter = mkOption {
        default = true;
        type = with types; bool;
        description = "Enables spin down for platter hard drives";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      hdparm
      smartmontools
    ];

    services = {
      udev = mkIf cfg.platter {
        path = [
          pkgs.hdparm
        ];
        extraRules = ''
          ACTION=="add|change", KERNEL=="sd[a-z]", ATTRS{queue/rotational}=="1", RUN+="${pkgs.hdparm}/bin/hdparm -S 108 -B 127 /dev/%k"
        '';
      };
    };
  };
}
