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
          vlan = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                filtering = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable VLAN filtering on the bridge.";
                };
                defaultPVID = mkOption {
                  type = types.nullOr (types.either types.int (types.enum [ "none" ]));
                  default = null;
                  description = "Default PVID for the bridge. Use 'none' to disable or an integer for a specific VLAN ID.";
                  example = "none";
                };
                bridgeVLAN = mkOption {
                  type = types.nullOr (types.submodule {
                    options = {
                      pvid = mkOption {
                        type = types.nullOr types.int;
                        default = null;
                        description = "Port VLAN ID for the bridge interface itself.";
                        example = 230;
                      };
                      egressUntagged = mkOption {
                        type = types.listOf types.int;
                        default = [ ];
                        description = "List of VLAN IDs that should egress untagged from the bridge.";
                        example = [ 230 ];
                      };
                    };
                  });
                  default = null;
                  description = "VLAN configuration for the bridge interface itself (appears in 30-*.network).";
                };
                portVLANs = mkOption {
                  type = types.attrsOf (types.submodule {
                    options = {
                      vlans = mkOption {
                        type = types.listOf types.int;
                        default = [ ];
                        description = "List of VLAN IDs allowed on this bridge port.";
                        example = [ 230 100 ];
                      };
                      pvid = mkOption {
                        type = types.nullOr types.int;
                        default = null;
                        description = "Port VLAN ID for this port.";
                        example = 230;
                      };
                      egressUntagged = mkOption {
                        type = types.listOf types.int;
                        default = [ ];
                        description = "List of VLAN IDs that should egress untagged from this port.";
                        example = [ 230 ];
                      };
                    };
                  });
                  default = { };
                  description = "Per-port VLAN configuration for bridge ports (appears in 10-*.network).";
                };
              };
            });
            default = null;
            description = "VLAN-aware bridge configuration.";
          };
        };
      });
      default = { };
      description = "Multiple named bridge configurations";
    };
  };

  config = let
    networks = config.host.network.networks or { };
    allPorts = lib.foldl' (acc: bName:
      let
        b = bridges.${bName};
        brName = if b.name == null then bName else b.name;
        portList = b.interfaces or [ ];
        portEntries = map (ifn: {
          port = ifn;
          bridge = brName;
          vlanConfig = if b.vlan != null && b.vlan.portVLANs ? ${ifn} then
            b.vlan.portVLANs.${ifn}
          else null;
          isVlanAware = b.vlan != null && b.vlan.filtering;
        }) portList;
      in lib.foldl' (pacc: pentry:
        let
          existing = pacc.${pentry.port} or { bridges = [ ]; vlanConfigs = [ ]; isVlanAware = false; };
        in pacc // {
          ${pentry.port} = {
            bridges = existing.bridges ++ [ pentry.bridge ];
            vlanConfigs = existing.vlanConfigs ++ (if pentry.vlanConfig != null then [ pentry.vlanConfig ] else [ ]);
            isVlanAware = existing.isVlanAware || pentry.isVlanAware;
          };
        }
      ) acc portEntries
    ) { } (builtins.attrNames bridges);

    portNetworkFiles = concatLists (mapAttrsToList (ifn: portInfo:
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

        isSharedVlanPort = (builtins.length portInfo.bridges > 1) && portInfo.isVlanAware;
        mergedVLANConfig = if isSharedVlanPort then
          let
            allVlans = lib.unique (concatLists (map (cfg: cfg.vlans) portInfo.vlanConfigs));
            allPvids = lib.filter (x: x != null) (map (cfg: cfg.pvid) portInfo.vlanConfigs);
            allEgress = lib.unique (concatLists (map (cfg: cfg.egressUntagged) portInfo.vlanConfigs));
          in {
            vlans = allVlans;
            pvid = if allPvids != [ ] then builtins.head allPvids else null;
            egressUntagged = allEgress;
          }
        else if portInfo.vlanConfigs != [ ] then
          builtins.head portInfo.vlanConfigs
        else null;

        bridgeVLANLines = if mergedVLANConfig != null && portInfo.isVlanAware then
          let
            vlanLines = map (vlanId: "VLAN=" + builtins.toString vlanId) mergedVLANConfig.vlans;
            pvidLine = if mergedVLANConfig.pvid != null then
              [ ("PVID=" + builtins.toString mergedVLANConfig.pvid) ]
            else [ ];
            egressLines = if mergedVLANConfig.egressUntagged != [ ] then
              [ ("EgressUntagged=" + concatStringsSep " " (map builtins.toString mergedVLANConfig.egressUntagged)) ]
            else [ ];
          in [ "" "[BridgeVLAN]" ] ++ vlanLines ++ pvidLine ++ egressLines
        else [ ];

        bridgeLines = if isSharedVlanPort then
          map (br: "Bridge=" + br) portInfo.bridges
        else
          [ ("Bridge=" + builtins.head portInfo.bridges) ];

        path = "systemd/network/10-" + ifn + ".network";
        text = lib.concatStringsSep "\n" (matchLines ++ [ "" ] ++ [
          "[Link]"
          "RequiredForOnline=enslaved"
          ""
          "[Network]"
        ] ++ bridgeLines ++ bridgeVLANLines ++ [ "" ]);
      in [{
        name = path;
        value = { text = text; };
      }]
    ) allPorts);

    bList = mapAttrsToList (bName: b:
      let
        brName = if b.name == null then bName else b.name;
        netdevPath = "systemd/network/20-" + brName + ".netdev";
        bridgeSection = if b.vlan != null && b.vlan.filtering then
          let
            defaultPVIDLine = if b.vlan.defaultPVID != null then
              "DefaultPVID=" + (if b.vlan.defaultPVID == "none" then "none" else builtins.toString b.vlan.defaultPVID)
            else "";
          in ''

            [Bridge]
            VLANFiltering=1
            ${defaultPVIDLine}''
        else "";

        netdevText = let
          macToEmit = if b ? mac then b.mac else null;
        in ''
          [NetDev]
          Name=${brName}
          Kind=bridge
          ${if macToEmit != null then "MACAddress=${macToEmit}" else ""}${bridgeSection}
        '';

        bridgeNetwork = let
          netCfg = if networks ? ${brName} then networks.${brName} else null;
          bridgeVLANLines = if b.vlan != null && b.vlan.bridgeVLAN != null then
            let
              bvlan = b.vlan.bridgeVLAN;
              pvidLine = if bvlan.pvid != null then
                [ ("PVID=" + builtins.toString bvlan.pvid) ]
              else [ ];
              egressLines = if bvlan.egressUntagged != [ ] then
                [ ("EgressUntagged=" + concatStringsSep " " (map builtins.toString bvlan.egressUntagged)) ]
              else [ ];
            in [ "" "[BridgeVLAN]" ] ++ pvidLine ++ egressLines
          else [ ];

          networkLines = if netCfg != null then
            let
              dhcpLine = if netCfg.type == "dynamic" then [ "DHCP=yes" ] else [ ];
              dnsLines = if netCfg.type == "static" && netCfg.dns != null then
                map (dns: "DNS=" + dns) netCfg.dns
              else [ ];
              domainsLine = if netCfg.domains != null then
                [ ("Domains=" + concatStringsSep " " netCfg.domains) ]
              else [ ];
              extraConfig = if netCfg.networkConfig != null then
                map (k: k + "=" + builtins.toString netCfg.networkConfig.${k}) (builtins.attrNames netCfg.networkConfig)
              else [ ];
            in dhcpLine ++ dnsLines ++ domainsLine ++ extraConfig
          else [ ];

          addressLines = if netCfg != null && netCfg.type == "static" && netCfg.ip != null then
            [ "" "[Address]" ("Address=" + netCfg.ip) ]
          else [ ];

          routeLines = if netCfg != null && netCfg.type == "static" && netCfg.gateway != null then
            let
              is32 = (builtins.match ".*/32$" netCfg.ip) != null;
              gwOnLink = if netCfg.gatewayOnLink != null then netCfg.gatewayOnLink else is32;
            in [ "" "[Route]" ("Gateway=" + netCfg.gateway) ] ++ (if gwOnLink then [ "GatewayOnLink=true" ] else [ ])
          else [ ];

          path = "systemd/network/30-" + brName + ".network";
          text = lib.concatStringsSep "\n" ([
            "[Match]"
            ("Name=" + brName)
            ""
            "[Network]"
          ] ++ networkLines ++ addressLines ++ routeLines ++ bridgeVLANLines ++ [ "" ]);

        in if netCfg != null then [{
          name = path;
          value = { text = text; };
        }] else [ ];

      in [{
        name = netdevPath;
        value = { text = netdevText; };
      }] ++ bridgeNetwork) bridges;

    envEtc = listToAttrs (portNetworkFiles ++ concatLists bList);
  in mkIf config.systemd.network.enable { environment.etc = envEtc; };
}
