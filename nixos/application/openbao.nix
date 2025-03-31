{config, lib, pkgs, ...}:

let
  cfg = config.host.application.openbao;
in
  with lib;
{
  options = {
    host.application.openbao = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables Openbao secrets manager";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      openbao
    ];
  };
}
