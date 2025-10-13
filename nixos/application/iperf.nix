{config, lib, pkgs, ...}:

let
  cfg = config.host.application.iperf;
in
  with lib;
{
  options = {
    host.application.iperf = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables iperf";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      iperf
    ];
  };
}