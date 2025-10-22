{ config, lib, ... }:

with lib;

{
  options = {
    host.network.networks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
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
          gatewayOnLink = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Optional override for whether the route's GatewayOnLink should be set. If null, it's auto-set for /32 addresses.";
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
    bridges = config.host.network.bridges or { };

    mkEntry = name: net:
      let
        baseNetworkConfig = (if net.domains != null then {
          Domains = concatStringsSep " " net.domains;
        } else { }) // (if net.networkConfig != null then net.networkConfig else { });
        networkConfig = baseNetworkConfig // (if net.type == "dynamic" then {
          DHCP = "yes";
        } else if net.type == "static" then {
          DNS = if net.dns != null then net.dns else null;
        } else { });
        networkConfigFiltered = let nc = filterAttrs (k: v: v != null) networkConfig; in
          if builtins.length (builtins.attrNames nc) == 0 then null else nc;
        value = let
          explicitMatch = if net.match != null then net.match else null;
          bridgeMac = if explicitMatch == null || explicitMatch.mac == null then
            if bridges ? name then
              let b = bridges.${name};
                firstIf = if b.interfaces != null && b.interfaces != [] then builtins.head b.interfaces else null;
              in if firstIf != null && interfaces ? firstIf && interfaces.${firstIf} ? match && interfaces.${firstIf}.match != null && interfaces.${firstIf}.match.mac != null then
                interfaces.${firstIf}.match.mac
              else null
            else null
          else null;

          m = if explicitMatch != null then explicitMatch else null;

          matchAttrs = if m != null then filterAttrs (k: v: v != null) {
            Name = m.name;
            MACAddress = m.mac;
            PermanentMACAddress = m.permanentMac;
            Path = m.path;
            OriginalName = m.originalName;
          }
          else if bridgeMac != null then { MACAddress = bridgeMac; }
          else { Name = name; };

        in let
          is32 = if net.ip != null then (builtins.match ".*/32$" net.ip) != null else false;
          gwOnLink = if net.gatewayOnLink != null then net.gatewayOnLink else is32;
        in {
          matchConfig = matchAttrs;
          networkConfig = networkConfigFiltered;
          routes = if net.type == "static" && net.gateway != null then [{
            Gateway = net.gateway;
            GatewayOnLink = if gwOnLink then true else false;
          }] else [ ];
          addresses = if net.type == "static" && net.ip != null then
            [ { Address = net.ip; } ]
          else [ ];
          dhcpV4Config = if net.dhcpClientIdentifier != null then {
            ClientIdentifier = net.dhcpClientIdentifier;
          } else { };
          linkConfig = if net.type == "static" then { RequiredForOnline = "routable"; } else { };
        };
      in {
        name = name;
        value = filterAttrs (k: v: v != { } && v != null) value;
      };

    entries = mapAttrsToList (n: v: mkEntry n v) networks;
  in {
    systemd.network.enable = mkForce
      (if config.host.network.manager != null then
        (config.host.network.manager == "systemd-networkd"
         || config.host.network.manager == "networkd"
         || config.host.network.manager == "both")
      else
        (builtins.length (builtins.attrNames networks) > 0));

    systemd.network.networks = mkIf config.systemd.network.enable
      (listToAttrs (map (e: { name = "30-" + e.name; value = e.value; }) entries));
  };
}
