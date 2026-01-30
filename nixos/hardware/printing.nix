{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.printing;
in
  with lib;
{
  options = {
    host.hardware.printing = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables and drivers for printing";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      printing = {
        enable = mkDefault true;
        drivers = with pkgs;
        [
          gutenprint
          hplip
        ];
      };

      avahi = { # required for network discovery of printers
        enable = mkDefault true;
        nssmdns4 = mkDefault true; # resolve .local domains for printers
        openFirewall = mkDefault true;
      };
    };

    host.filesystem.impermanence.directories = mkIf config.host.filesystem.impermanence.enable [
      "/var/lib/cups"          # CUPS
    ];
  };
}
