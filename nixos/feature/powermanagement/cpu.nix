{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.powermanagement.cpu;
in
  with lib;
{
  options = {
    host.feature.powermanagement.cpu = {
      enable = mkOption {
        default = true;
        type = with types; bool;
        description = "Enable CPU frequency management";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      extraModulePackages = with config.boot.kernelPackages; [
        #cpupower
        #pkgs.cpupower-gui
      ];
    };

    environment.systemPackages = with pkgs; [
      power-profiles-daemon
    ];

    services = {
      auto-cpufreq.enable = !config.host.feature.powermanagement.tlp.enable;
      power-profiles-daemon.enable = !config.host.feature.powermanagement.tlp.enable;
    };
  };
}
