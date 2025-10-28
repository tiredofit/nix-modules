{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    host.network.interfaces = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          match = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                name = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by runtime interface name.";
                  example= "enp3s0f0";
                };
                mac = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by current MAC address.";
                  example = "00:01:02:ab:cd:ef";
                };
                permanentMac = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by permanent hardware MAC.";
                  example = "00:01:02:ab:cd:ef";
                };
                path = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by device path.";
                  example = "/sys/devices/pci0000:00/0000:00:1f.6/net/enp0s31f6";
                };
                originalName = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by original/kernel name.";
                  example = "eth0";
                };
              };
            });
            default = null;
            description = "Optional structured match configuration for selecting the physical device to bind to.";
          };
          mtu = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "MTU size for the interface";
            example = "1500";
          };
          wakeOnLan = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "WakeOnLan flags for Link";
            example = "pudg";
          };
          linkLocalAddressing = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Support 169.254.0.0/16 communication.";
          };
          vlans = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "Optional list of VLAN device names attached to this interface.";
            example = [ "vlan100" "vlan200" ];
          };
        };
      });
      default = { };
    };
  };

  config = let ifaces = config.host.network.interfaces or { };
    in let
      linkFiles = mapAttrsToList (n: i:
        let
          path = "systemd/network/05-" + n + ".link";
          m = if (i ? match && i.match != null) then i.match else null;
          present = if m != null then lib.filterAttrs (k: v: v != null) {
            Name = if m.name != null then m.name else null;
            MACAddress = if m.mac != null then m.mac else null;
            PermanentMACAddress = if m.permanentMac != null then m.permanentMac else null;
            Path = if m.path != null then m.path else null;
            OriginalName = if m.originalName != null then m.originalName else null;
          } else { };
          presentNames = builtins.attrNames present;
          kvLines = map (k: k + "=" + builtins.toString (builtins.getAttr k present)) presentNames;
          matchLines = if presentNames == [] then [] else (["[Match]"] ++ kvLines);
          linkLines = [ "[Link]" ("Name=" + n) ];
          text = lib.concatStringsSep "\n" (matchLines ++ [""] ++ linkLines);
        in { name = path; value = { text = text; }; }) ifaces;
    in {
    assertions = concatLists (map (name:
      let i = ifaces.${name};
      in [{
        assertion = ((i ? mac && i.mac != null) || (i ? matchName && i.matchName != null) || (i ? match && i.match != null));
        message = "[host.network.interfaces." + name + "] Provide either 'mac', 'matchName' or 'match' to identify the interface";
      }]) (builtins.attrNames ifaces));
      environment.etc = mkIf config.systemd.network.enable (listToAttrs linkFiles);
  };
}
