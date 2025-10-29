# Network configuration

For host.networking.manager="systemd-networkd".
- Define physical `interfaces` (and VLANs) (`05-` and `10-` prefixes)
- Declare `bridges` devices that form the topology (`20-*.netdev` files)
- Declare networks-level `networks` entries which bind devices together and provide addressing

- Device naming and matching:
  - `phys0` in the example is a logical name used throughout the configuration. Prefer stable matching by `mac` where possible so names don't change when the kernel orders devices differently. `match.name` can be used with the kernel/udev name (for example `enp1s0f0`) or with glob patterns (`vm-lan-*`).

    - `interfaces` section:
      - Describes physical NICs and any VLAN children. Each VLAN has an `id` (the numeric VLAN tag) and a `name` — the logical device name that other parts of the config refer to (for bridge membership, network matching, etc.).
      - Fields like `mtu`, `wakeOnLan`, and `linkLocalAddressing` are optional and passed through to the low-level interface provisioning.
      - `vlans` assign VLANs, creating multiple interfaces

```nix
  network = {
    interfaces = {
      phys0 = { # physical NIC renamed to phys0 via match.mac (preferred) or match.name
        match = {
          #name = "enp1s0f0";
          mac = "ab:cd:ef:01:02:03";
        };
        mtu = null;
        wakeOnLan = null;
        linkLocalAddressing = null;
        vlans = [
          "lan"
          "iot"
          "guest"
          "server"
          "vpn"
        ];
      };
    };
```

    - `vlans` section:
      -  VLAN declarations (topology). VLAN netdevs are created by the vlan module.
      - Declares VLAN netdevs to that bridge. `id` is a number between 2 and 4096.
      - `match.name` can be left null if the `vlans` is authoritative. When present, `match.name` controls which runtime device the `networks` and `bridges` matching will look for.

```nix
    vlans = {
      lan = {
        id = 100;
      };
      iot = {
        id = 200;
      };
      guest = {
        name = guest;
        id = 300;
      };
      server = {
        name = server;
        id = 400;
      };
      vpn = {
        id = 500;
      };
    };
```

    - `bridges` section:
      - Bridge declarations (topology). Bridge netdevs are created by the bridge module.
      - `interfaces` lists the device names (physical or VLAN names) to attach to that bridge. `stp` controls Spanning Tree Protocol if you are connecting multiple switches/bridges.
      - `match.name` can be left null if the bridge `name` is authoritative. When present, `match.name` controls which runtime device the `networks` matching will look for.

```nix
    bridges = {
      br-lan = {
        name = "br-lan";
        interfaces = [
          "phys0"
          "vlan-lan"
        ];
        match = {
          name = null;
          mac = null;
        };
        stp = false;
      };
      br-iot = {
        name = "br-iot";
        interfaces = [
          "vlan-iot"
        ];
        stp = false;
      };
      br-guest = {
        name = "br-guest";
        interfaces = [
          "vlan-guest"
        ];
        stp = false;
      };
      br-server = {
        name = "br-server";
        interfaces = [
          "vlan-server"
        ];
        stp = false;
      };
      br-vpn = {
        name = "br-vpn";
        interfaces = [
          "vlan-vpn"
        ];
        stp = false;
      };
    };
```

    - `networks` section:
      - Uses `match.name` and others to select devices.
      - The `type` field (seen as `static`/`unmanaged` in the example) controls whether the host assigns an address. `static` entries include `ip`, `gateway`, and `dns`. `unmanaged` means "bring the interface up but don't assign IPs". You can also use DHCP by setting `type = "dynamic"` in entries where that is supported by the module.

```nix
    networks = {
      # assign VLAN devices to physical device (VLAN member setup)
      phys0 = {
        type = "unmanaged"
      };

      phys0.lan = {
        match.name = { "lan" };
        type = "dynamic";
      };

      phys0.guest = {
        match.name = { "lan" };
        type = "unmanaged";
      };

      phys0.iot = {
        match.name = { "iot" };
        type = "static";
        ip = "192.168.2.20/24";
        gateway = "192.168.2.1";
        dns = [ "192.168.2.1" ];
      };

      phys0.server = {
        match.name = { "server" };
        type = "static";
        ip = "192.168.3.20/24";
      };

      phys0.vpn = {
        match.name = { "vpn" };
        type = "dynamic";
      };
    };
  };
```

## Bridging gotchas

By default the bridge module will emit a deterministic MAC for a bridge by deriving it from the first enslaved interface's configured MAC (if that interface has a `match.mac` configured). This ensures the bridge gets a stable hardware address across boots which can be useful if other parts of your configuration match by MAC.

If you prefer to control the bridge MAC explicitly, set `mac = "..."` on the bridge declaration. Use a locally-administered unicast address (set the second-least-significant bit of the first octet to 1).

```nix
    bridges = {
      br-lan = {
        name = "br-lan";
        mac = "02:0a:5a:00:a8:69";
        interfaces = [
                       "phys0"
                       "vlan-lan"
                     ];
        stp = false;
      };
    };
```

## Alternate Bridge and VLAN configuration

### Example 1

- Create bridges for physical NIC, map br-quad1-4 to locally run VM
- Locally run VM tags quad2 traffic to run VLANs
- Create Bridges to seperate VLANs and make available for containers VMs

```
    network = {
      hostname = "vmserver";
      manager = "both";
      interfaces = {
        onboard = {
          match = {
            mac = "00:01:02:03:04:05";
          };
        };
        quad1 = {
          match = {
            mac = "00:E0:EO:EO:EO:01";
          };
        };
        quad2 = {
          match = {
            mac = "00:E0:EO:EO:EO:02";
          };
        };
        quad3 = {
          match = {
            mac = "00:E0:EO:EO:EO:03";
          };
        };
        quad4 = {
          match = {
            mac = "00:E0:EO:EO:EO:04";
          };
        };
        br-quad2 = { # Create VLAN sub-interfaces on br-quad2
          match = {
            name = "br-quad2";
          };
          vlans = [
            "vlan100"
            "vlan200"
            "vlan300"
            #"vlan400"
            "vlan500"
          ];
        };
      };
      vlans = {
        vlan100 = {
          id = 100;
        };
        vlan200 = {
          id = 200;
        };
        vlan300 = {
          id = 300;
        };
        #vlan400 = {
        #  id = 400;
        #};
        vlan500 = {
          id = 500;
        };
      };
      bridges = {
        br-onboard = {
          interfaces = [ "onboard" ];
          match = {
            name = "onboard";
          };
        };
        br-quad1 = {
          interfaces = [ "quad1" ];
          match = {
            name = "quad1";
          };
        };
        br-quad2 = {
          interfaces = [ "quad2" ];
          match = {
            name = "quad2";
          };
        };
        br-quad3 = {
          interfaces = [ "quad3" ];
          match = {
            name = "quad3";
          };
        };
        br-quad4 = {
          interfaces = [ "quad4" ];
          match = {
            name = "quad4";
          };
        };
        br-vlan100= { # VLAN-specific bridges - Built on VLAN interfaces on br-quad2
          interfaces = [ "vlan100" ];
        };
        br-vlan200 = {
          interfaces = [ "vlan200" ];
        };
        br-vlan300 = {
          interfaces = [ "vlan300" ];
        };
        #br-vlan400 = {
        #  interfaces = [ "vlan400" ];
        #};
        br-vlan500 = {
          interfaces = [ "vlan500" ];
        };
      };
      networks = {
        onboard = {
          type = "dynamic";
          match = {
            name = "br-onboard";
          };
        };
        quad1 = {
          type = "unmanaged";
          match = {
            name = "br-quad1";
          };
        };
        quad2 = {
          type = "unmanaged";
          match = {
            name = "br-quad2";
          };
        };
        quad3 = {
          type = "unmanaged";
          match = {
            name = "br-quad3";
          };
        };
        quad4 = {
          type = "unmanaged";
          match = {
            name = "br-quad4";
          };
        };
        vlan100 = {
          type = "dynamic";
          match = {
            name = "br-vlan100";
          };
        };
        vlan200 = {
          type = "dynamic";
          match = {
            name = "br-vlan200";
          };
        };
        vlan300 = {
          type = "dynamic";
          match = {
            name = "br-vlan300";
          };
        };
        #vlan400 = {
        #  type = "dynamic";
        #  match = {
        #    name = "br-vlan400";
        #  };
        #};
        vlan500 = {
          type = "dynamic";
          match = {
            name = "br-vlan500";
          };
        };
      };
```

#### Virtual Machine - Same Host

```
    network = {
      firewall.fail2ban.enable = false;
      hostname = "vm-servedonserver";
      interfaces = {
        enp0 = {
          match = {
            mac = "02:01:01:02:DD";
          };
        };
        veth0 = { # Connected to server br-quad2
          match = {
            mac = "02:02:02:02:02";
          };
        };
        vveth = { # Connected to server br-vlan200
          match = {
            mac = "00:02:03:04:60";
          };
        };
        br-veth0 = { # Create VLAN sub-interfaces on br-veth0 (receives tagged traffic from Server)
          match = {
            name = "br-veth0";
          };
          vlans = [
            "vlan200"
            "vlan300"
            "vlan500"
          ];
        };
      };
      vlans = {
        vlan200 = {
          id = 200;
        };
        vlan300 = {
          id = 300;
        };
        vlan500 = {
          id = 500;
        };
      };
      bridges = {
        br-veth0 = { # Bridge veth0 to receive all tagged VLAN traffic from Server br-quad2
          interfaces = [ "veth0" ];
        };
        br-vlan200 = { # Then create VLAN-specific bridges for containers/VMs
          interfaces = [ "vlan200" ];
        };
        br-vlan300 = {
          interfaces = [ "vlan300" ];
        };
        br-vlan500 = {
          interfaces = [ "vlan500" ];
        };
      };
      networks = {
        enp0 = {
          type = "dynamic";
        };
        veth0-bridge = { # veth0 is bridged (br-veth0) - no IP on veth0 itself, br-veth0 is unmanaged - just passes VLAN traffic through
          type = "unmanaged";
          match = {
            name = "br-veth0";
          };
        };
        vveth = { # Direct access to VLAN 200 via vveth
          type = "dynamic";
        };
        vlan200 = {
          type = "dynamic"; # Host gets IP on VLAN 200
          match = {
            name = "br-vlan60";
          };
        };
        vlan300 = {
          type = "dynamic"; # host gets IP on VLAN 300
          match = {
            name = "br-vlan300";
          };
        };
        vlan500 = {
          type = "dynamic";  # host gets IP on VLAN 500
          match = {
            name = "br-vlan500";
          };
        };
      };
    };

### Example 2

- Subinterface for tagged VLAN

```
   network = {
      interfaces = {
        veth0 = {
          match = {
            mac = "03:03:03:03:03:03";
          };
          vlans = [
            "vlan60"
          ];
        };
      };
      vlans = {
        vlan60 = {
          id = 60;
        };
      };
      networks = {
        veth0 = {
          type = "unmanaged";
        };
        "veth0.60" = {
          match.name = "vlan60";
          type = "dynamic";
        };
      };
    };
```
