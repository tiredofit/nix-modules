{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    host.network.vlans = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption {
            type = types.int;
            description = "VLAN ID";
            example = "100";
          };
          name = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Name of VLAN device";
          };
        };
      });
      default = { };
      description = "VLAN definitions (name optional, id required).";
    };
  };

  config = let
    vlans = config.host.network.vlans or { };
    interfaces = config.host.network.interfaces or { };
    vlanNetdevs = concatLists (mapAttrsToList (vn: v:
      let
        vlanName = if v ? name && v.name != null then v.name else vn;
        path = "systemd/network/20-" + vlanName + ".netdev";
        netdevText = ''[NetDev]
Name=${vlanName}
Kind=vlan

[VLAN]
Id=${builtins.toString v.id}
'';
        entries = if v.id == 0 then throw "VLAN id cannot be 0" else [{ name = path; value = { text = netdevText; }; }];
      in entries) vlans);
        parentVlanNetworks = concatLists (mapAttrsToList (ifn: ifcfg:
      let
        ifaceVlans = if ifcfg ? vlans && builtins.isList ifcfg.vlans then ifcfg.vlans else [ ];
        path = "systemd/network/25-" + ifn + ".network";
        vlanLines = if ifaceVlans == [ ] then [] else map (vname: "VLAN=" + vname) ifaceVlans;
        text = lib.concatStringsSep "\n" (
          [ "[Match]" ("Name=" + ifn) "" "[Network]" ] ++ vlanLines
        );
  in if ifaceVlans == [ ] then [] else [{ name = path; value = { text = text; }; }]) interfaces);

    allFiles = vlanNetdevs ++ parentVlanNetworks;
    envEtc = listToAttrs allFiles;
  in mkIf config.systemd.network.enable { environment.etc = envEtc; };
}
