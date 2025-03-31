{config, lib, pkgs, ...}:

let
  cfg = config.host.service.coredns;
in
  with lib;
{
  options = {
    host.service.coredns = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "DNS Server";
      };
      service.enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Auto start on server start";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      coredns
    ];

    services = mkIf cfg.service.enable {
      coredns = {
        enable = mkIf cfg.service.enable;
        config = ''
           . {
               whoami
             }
        '';
        extraArgs = [
        ];
      };
    };
  };
}
