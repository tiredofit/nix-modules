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

    mkEntry = name: net:
      let
        baseNetworkConfig = (if net.domains != null then {
          Domains = concatStringsSep " " net.domains;
        } else { }) // (if net.networkConfig != null then net.networkConfig else { });
        networkConfig = baseNetworkConfig // (if net.type == "dynamic" then {
          DHCP = "yes";
        } else if net.type == "static" then {
          Gateway = net.gateway;
          DNS = if net.dns != null then concatStringsSep " " net.dns else null;
        } else { });
        value = {
          matchConfig = if net.match != null then
            let m = net.match; in filterAttrs (k: v: v != null) {
              Name = m.name;
              MACAddress = m.mac;
              PermanentMACAddress = m.permanentMac;
              Path = m.path;
              OriginalName = m.originalName;
            }
          else { Name = name; };
          networkConfig = filterAttrs (k: v: v != null) networkConfig;
          addresses = if net.type == "static" && net.ip != null then
            [ { Address = net.ip; } ]
          else [ ];
          dhcpV4Config = if net.dhcpClientIdentifier != null then {
            ClientIdentifier = net.dhcpClientIdentifier;
          } else { };
        };
      in {
        name = name;
        value = filterAttrs (k: v: v != { } && v != null) value;
      };

    entries = mapAttrsToList (n: v: mkEntry n v) networks;
  in {
    networking.useNetworkd = mkDefault
      (if config.host.network.manager != null then
        config.host.network.manager == "systemd-networkd"
      else
        (builtins.length (builtins.attrNames networks) > 0));

    systemd.network.networks = mkIf config.networking.useNetworkd
      (listToAttrs (map (e: { name = "30-" + e.name; value = e.value; }) entries));
  };
}
