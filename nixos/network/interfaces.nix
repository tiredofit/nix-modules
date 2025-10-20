{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    host.network.interfaces = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          # Structured match block: prefer using these fields to select the
          # device. This is the canonical place to specify match criteria such
          # as name, mac, permanentMac, path and originalName. We keep the
          # legacy `mac` and `matchName` at the top-level for compatibility.
          match = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                name = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by runtime interface name (Name=).";
                };
                mac = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by current MAC address (MACAddress=).";
                };
                permanentMac = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by permanent hardware MAC (PermanentMACAddress=).";
                };
                path = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by device path (Path=).";
                };
                originalName = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match by original/kernel name (OriginalName=).";
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
            type = types.nullOr (types.attrsOf (types.submodule {
              options = {
                id = mkOption {
                  type = types.int;
                  default = 0;
                  description = "VLAN ID";
                  example = "100";
                };
                name = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Optional explicit name for the VLAN device";
                  example = "vlan-lan";
                };
              };
            }));
            default = null;
            description = "Optional VLAN topology attached to this interface.";
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
          path = "systemd/network/10-" + n + ".link";
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

    # Emit explicit .link files into /etc/systemd/network so they contain
    # both [Match] and [Link] sections. The previous approach using
    # `systemd.network.links` did not render match criteria into the file on
    # disk on all systems, so we build the files ourselves here. We still
    # prefer the structured `match` submodule, with legacy fallbacks allowed.
      environment.etc = mkIf config.networking.useNetworkd (listToAttrs linkFiles);
  };
}
