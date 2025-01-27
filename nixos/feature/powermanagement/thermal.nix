{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.powermanagement.thermal;
  thermald =
    if (config.host.hardware.cpu == "intel")
    then true
    else false;
in
  with lib;
{
  options = {
    host.feature.powermanagement.thermal = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables thermal management";
      };
      thermald = mkOption {
        default = thermald;
        type = with types; bool;
        description = "Enables thermal management for Intel Architecture";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      thermald.enable = thermald;
    };
  };
}
