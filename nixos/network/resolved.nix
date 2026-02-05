{config, lib, pkgs, ...}:

let
  cfg = config.host.network.resolved;
in
  with lib;
{
  options = {
    host.network.resolved = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable systemd-resolved resolution";
      };
      resolveMulticastDNS = mkOption {
        type = with types; bool;
        default = false;
        description = "Enable resolution of Multicast DNS.";
      };
      resolveLLMNR = mkOption {
        type = with types; bool;
        default = false;
        description = "Enable Link-Local Multicast Name Resolution.";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      resolved = {
        enable = mkDefault true;
        settings = {
          Resolve = {
            MulticastDNS = mkDefault cfg.resolveMulticastDNS;
            LLMNR = mkDefault cfg.resolveLLMNR;
          };
        };
      };
    };
  };
}
