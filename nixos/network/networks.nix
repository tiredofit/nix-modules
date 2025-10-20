{ config, lib, ... }:

with lib;

{
  options = {
    host.network.networks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          # Structured match block for network-level matching (preferred).
          # Use `match.name` to set Name=, or other keys for MAC/Path/etc.
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
            description = "Optional structured match config for this network (maps to systemd [Match] keys).";
          };
          networkConfig = mkOption {
            type = types.nullOr types.attrs;
            default = null;
            description = "Optional extra [Network] keys to merge into the generated network unit.";
            example = {
              Bridge = "br-lan";
            };
          };
          type = mkOption {
            type = types.nullOr (types.enum [ "static" "dynamic" "unmanaged" ]);
            default = null;
            description = "Addressing type for this network. - Unmanaged or null means no addressing configured.";
            example = "static";
          };
          ip = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "IP address with CIDR suffix.";
            example = "192.168.1.10/24";
          };
          gateway = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Gateway IP address.";
            example = "192.168.1.1";
          };
          dns = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "List of DNS server IP addresses.";
            example = [ "1.1.1.1" "1.0.0.1" ];
          };
          domains = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "Search domains for this network.";
            example = [ "example.com" "local" ];
          };
          dhcpClientIdentifier = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "DHCP client identifier to use for this network.";
            example = "my-client-id";
          };
        };
      });
      default = { };
      description = "Addressing and network-level configuration. Keys are device names (eg. 'br0', 'onboard', 'onboard.100').";
    };
  };

  config = let
    networks = config.host.network.networks or { };
    interfaces = config.host.network.interfaces or { };

    mkEntry = name: net:
      let
        iface = if interfaces ? name then interfaces.${name} else { };
        netconfBase = if net.domains != null then {
          Domains = lib.concatStringsSep " " net.domains;
        } else
          { };
        mergedNetConf = netconfBase
          // (if net.networkConfig != null then net.networkConfig else { });
        matchConfig = if net.match != null then
          let m = net.match; in lib.filterAttrs (k: v: v != null) {
            Name = if m.name != null then m.name else null;
            MACAddress = if m.mac != null then m.mac else null;
            PermanentMACAddress = if m.permanentMac != null then m.permanentMac else null;
            Path = if m.path != null then m.path else null;
            OriginalName = if m.originalName != null then m.originalName else null;
          }
        else if iface ? match then
          let m = iface.match; in lib.filterAttrs (k: v: v != null) {
            Name = if m.name != null then m.name else null;
            MACAddress = if m.mac != null then m.mac else null;
            PermanentMACAddress = if m.permanentMac != null then m.permanentMac else null;
            Path = if m.path != null then m.path else null;
            OriginalName = if m.originalName != null then m.originalName else null;
          }
        else
          # Fallback: match by the logical name of the network entry so that
          # mapping units attach to devices that have been renamed to the
          # logical name (eg. via .link files). This is a safe default for
          # configurations that declare an interface and a network with the
          # same key but don't provide explicit match criteria.
          { Name = name; };

        mappingValue = lib.removeAttrs (lib.mkForce {
          matchConfig = matchConfig;
          networkConfig =
            (if mergedNetConf != null then mergedNetConf else { });
          linkConfig = lib.mkForce
            ((if iface ? mtu then { MTUBytes = toString iface.mtu; } else { })
              // (if iface ? wakeOnLan then {
                WakeOnLan = if iface.wakeOnLan then "yes" else "no";
              } else
                { }) // (if iface ? linkLocalAddressing then {
                  LinkLocalAddressing =
                    if iface.linkLocalAddressing then "yes" else "no";
                } else
                  { }));
        }) [ "dhcpV4Config" "address" "dns" "routes" ];
        addressingValue = lib.removeAttrs (lib.mkForce {
          matchConfig = matchConfig;
          dhcpV4Config = if net.dhcpClientIdentifier != null then {
            ClientIdentifier = net.dhcpClientIdentifier;
          } else
            { };
          address = if net.type == "static" then
            (if net.ip != null then [ net.ip ] else [ ])
          else
            [ ];
          dns =
            if net.type == "static" && net.dns != null then net.dns else [ ];
          routes = if net.type == "static" && net.gateway != null then [{
            Gateway = net.gateway;
            GatewayOnLink = true;
          }] else
            [ ];
        }) [ ];
      in {
        name = name;
        mapping = mappingValue;
        addressing = addressingValue;
      };

    entries = mapAttrsToList (n: v: mkEntry n v) networks;
  in {
    networking.useNetworkd = mkDefault
      (if config.host.network.manager != null then
        config.host.network.manager == "systemd-networkd"
      else
        (builtins.length (builtins.attrNames networks) > 0));

    # Emit a single 30-<name>.network per network that includes both the
    # mapping (match) and addressing (Network/Route) keys. This avoids a
    # situation where systemd-networkd loads the mapping file but the
    # addressing file either lacks a [Match] or isn't considered for the
    # matched device due to ordering. Keeping mapping+addressing together is
    # simpler and ensures addressing is applied when the mapping matches.
    systemd.network.networks = mkIf config.networking.useNetworkd (let
      combinedAttrs = map (e: {
        name = "30-" + e.name;
        value = e.mapping // e.addressing;
      }) entries;
    in listToAttrs combinedAttrs);
  };
}
