{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.powermanagement.battery;
in
  with lib;
{
  options = {
    host.feature.powermanagement.battery = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables battery management";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      upower = {
        enable = mkDefault true;
        percentageLow = mkDefault 15;
        percentageCritical = mkDefault 5;
        percentageAction = mkDefault 3;
        criticalPowerAction = mkDefault "Hibernate";
      };
    };
  };
}
