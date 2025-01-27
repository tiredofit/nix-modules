{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.powermanagement.powertop;
in
  with lib;
{
  options = {
    host.feature.powermanagement.powertop = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables adding powertop management tools";
      };
      startup = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables powertop daemon on startup";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      powertop
    ];

    systemd = {
      services = {
        powertop = mkIf cfg.startup {
          wantedBy = [ "multi-user.target" ];
          after = [ "multi-user.target" ];
          description = "Powertop tunings";
          path = [ pkgs.kmod ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = "yes";
            ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
          };
        };
      };
    };
  };
}
