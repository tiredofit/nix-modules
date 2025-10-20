{ config, lib, pkgs, ... }:

with lib;

let
  bridges = config.host.network.bridges or { };
  interfaces = config.host.network.interfaces or { };

  resolveIface = iface: let
    entry = if interfaces ? iface then interfaces.${iface} else null;
  in let
    firstNonNull = xs: builtins.head (builtins.filter (x: x != null) xs);
  matchCandidates = if entry != null && (entry ? match && entry.match != null) then [ entry.match.name entry.match.mac entry.match.permanentMac entry.match.path entry.match.originalName ] else [ ];
  in (if matchCandidates == [] then iface else firstNonNull matchCandidates);

  mkMatchAttrs = m: lib.filterAttrs (k: v: v != null) {
    Name = m.name;
    MACAddress = m.mac;
    PermanentMACAddress = m.permanentMac;
    Path = m.path;
    OriginalName = m.originalName;
  };

  bridgeMatchFor = b: if (b ? match && b.match != null) then mkMatchAttrs b.match else if ((b ? matchName && b.matchName != null) || (b ? mac && b.mac != null)) then lib.filterAttrs (k: v: v != null) {
    Name = if (b ? matchName) then b.matchName else null;
    MACAddress = if (b ? mac) then b.mac else null;
  } else null;

in {
  options = {
    host.network.bridges = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "The name of the bridge. If null, the attribute name is used.";
            example = "br0";
          };
          interfaces = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "List of interfaces to enslave to the bridge.";
            example = [ "eth0" "eth0.100" ];
          };
          match = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                name = mkOption { type = types.nullOr types.str; default = null; };
                mac = mkOption { type = types.nullOr types.str; default = null; };
                permanentMac = mkOption { type = types.nullOr types.str; default = null; };
                path = mkOption { type = types.nullOr types.str; default = null; };
                originalName = mkOption { type = types.nullOr types.str; default = null; };
              };
            });
            default = null;
            description = "Optional structured match for the bridge itself (maps to systemd [Match] on attachment).";
          };
          stp = mkOption {
            type = types.bool;
            default = false;
            description = "Enable Spanning Tree Protocol on the bridge.";
          };
          linkLocalAddressing = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to enable link-local (169.254/16) addressing on the bridge's attachment network. Defaults to false.";
          };
        };
      });
      default = { };
      description = "Multiple named bridge configurations";
    };
  };

  config = let
    bList = mapAttrsToList (bName: b:
      let
        brName = if b.name == null then bName else b.name;
        netdevPath = "systemd/network/20-" + brName + ".netdev";
        netdevLines = [
          "[NetDev]"
          ("Name=" + brName)
          "Kind=bridge"
          ""
        ];
        netdevLines2 = if (b ? mac && b.mac != null) then
          netdevLines ++ [
           "[Bridge]"
           ("MACAddress=" + b.mac)
          ]
        else
          netdevLines;
        netdevText = lib.concatStringsSep "\n" netdevLines2;
        ports = concatLists (map (ifn:
          let
            resolved = resolveIface ifn;
            path = "systemd/network/30-" + resolved + ".network";
            text = lib.concatStringsSep "\n" ([
              "[Match]"
              ("Name=" + resolved)
              ""
              "[Network]"
              ("Bridge=" + brName)
              (if (b ? linkLocalAddressing && b.linkLocalAddressing) then "LinkLocalAddressing=yes" else "LinkLocalAddressing=no")
              ""
            ]);
          in [ { name = path; value = { text = text; }; } ]) (b.interfaces or [ ]));

      in [{
        name = netdevPath;
        value = { text = netdevText; };
      }] ++ ports) bridges;

    envEtc = listToAttrs (concatLists bList);
  in mkIf config.networking.useNetworkd { environment.etc = envEtc; };
}
