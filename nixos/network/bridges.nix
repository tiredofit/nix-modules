{ config, lib, pkgs, ... }:

with lib;

let
  bridges = config.host.network.bridges or { };
  interfaces = config.host.network.interfaces or { };

  resolveIface = iface:
    let entry = if interfaces ? iface then interfaces.${iface} else null;
    in let
      firstNonNull = xs: builtins.head (builtins.filter (x: x != null) xs);
      matchCandidates =
        if entry != null && (entry ? match && entry.match != null) then [
          entry.match.name
          entry.match.mac
          entry.match.permanentMac
          entry.match.path
          entry.match.originalName
        ] else
          [ ];
    in (if matchCandidates == [ ] then iface else firstNonNull matchCandidates);

  mkMatchAttrs = m:
    lib.filterAttrs (k: v: v != null) {
      Name = m.name;
      MACAddress = m.mac;
      PermanentMACAddress = m.permanentMac;
      Path = m.path;
      OriginalName = m.originalName;
    };

  bridgeMatchFor = b:
    if (b ? match && b.match != null) then
      mkMatchAttrs b.match
    else if ((b ? matchName && b.matchName != null)
      || (b ? mac && b.mac != null)) then
      lib.filterAttrs (k: v: v != null) {
        Name = if (b ? matchName) then b.matchName else null;
        MACAddress = if (b ? mac) then b.mac else null;
      }
    else
      null;

in {
  options = {
    host.network.bridges = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.nullOr types.str;
            default = null;
            description =  "The name of the bridge. If null, the attribute name is used.";
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
                name = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match interface by name.";
                  example = "br0";
                };
                mac = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match interface by MAC address.";
                  example = "00:01:02:ab:cd:ef";
                };
                permanentMac = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match interface by permanent MAC address.";
                  example = "00:01:02:ab:cd:ef";
                };
                path = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Match interface by sysfs path.";
                  example = "/sys/devices/pci0000:00/0000:00:1f.6/net/enp0s31f6";
                };
                originalName = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  desciption = "Match interface by original name.";
                  example = "eth0";
                };
              };
            });
            default = null;
            description = "Optional structured match for the bridge itself";
          };
          mac = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional explicit MAC address to assign to the bridge.";
            example = "00:11:22:aa:bb:cc";
          };
          stp = mkOption {
            type = types.bool;
            default = false;
            description = "Enable Spanning Tree Protocol on the bridge.";
          };
          linkLocalAddressing = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to enable link-local (169.254/16) addressing on the bridge's attachment network.";
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
        netdevText = let
          macToEmit = if b ? mac then b.mac else null;
        in ''
          [NetDev]
          Name=${brName}
          Kind=bridge
          ${if macToEmit != null then "MACAddress=${macToEmit}" else ""}
        '';
        ports = concatLists (map (ifn:
          let
            iface = if interfaces ? ifn then interfaces.${ifn} else null;
            matchAttrs =
              if iface != null && iface ? match && iface.match != null then
                mkMatchAttrs iface.match
              else {
                Name = ifn;
              };
            matchLines = if matchAttrs == { } then
              [ ]
            else
              [ "[Match]" ]
              ++ map (k: k + "=" + matchAttrs.${k}) (attrNames matchAttrs);
            path = "systemd/network/10-" + ifn + ".network";
            text = lib.concatStringsSep "\n" (matchLines ++ [ "" ] ++ [
              "[Link]"
              "RequiredForOnline=enslaved"
              ""
              "[Network]"
              ("Bridge=" + brName)
              ""
            ]);
          in [{
            name = path;
            value = { text = text; };
          }]) (b.interfaces or [ ]));
      in [{
        name = netdevPath;
        value = { text = netdevText; };
      }] ++ ports) bridges;

    envEtc = listToAttrs (concatLists bList);
  in mkIf config.systemd.network.enable { environment.etc = envEtc; };
}
