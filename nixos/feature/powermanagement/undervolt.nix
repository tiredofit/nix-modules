{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.powermanagement.undervolt;
  undervolt =
    if (config.host.hardware.cpu == "intel")
    then true
    else false;
in
  with lib;
{
  options = {
    host.feature.powermanagement.undervolt = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables undervolting support for intel CPUs";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      undervolt = {
        enable = mkDefault undervolt;
        package = pkgs.undervolt;
        tempBat = mkDefault 65;
      };
    };
  };
}
