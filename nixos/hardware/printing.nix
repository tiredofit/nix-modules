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
      autodiscover = {
        enable = mkOption {
          default = false;
          type = with types; bool;
          description = "Enable mDNS and autodiscovery for network printers";
        };
      };
      drivers = {
        hp = {
          enable = mkOption {
            default = true;
            type = with types; bool;
            description = "Enable HP (hplip) driver";
          };
        };
        gutenprint = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable Gutenprint drivers";
          };
        };
        custom = mkOption {
          default = [];
          type = with types; listOf types.str;
          description = "Extra printer drivers to include (pkgs)";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    host.filesystem.impermanence.directories = mkIf config.host.filesystem.impermanence.enable [
      "/var/lib/cups"
    ];

    services = {
      avahi = {
        enable = mkDefault cfg.autodiscover.enable; # required for network discovery of printers
        nssmdns4 = mkDefault true;                  # resolve .local domains for printers
        openFirewall = mkDefault true;
      };

      printing = {
        enable = mkDefault true;
        drivers = with pkgs;
          let
            customDriverPkgs = map (n: builtins.getAttr n pkgs) cfg.drivers.custom;
          in
          (  optional cfg.drivers.gutenprint.enable gutenprint
             ++
             optional cfg.drivers.hp.enable hplip
          )
          ++ customDriverPkgs;
      };
    };
  };
}
