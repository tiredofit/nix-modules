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
        vlans = {
          lan = {
            id = 11;
            name = "vlan-lan";
          };
          iot = {
            id = 2;
            name = "vlan-iot";
          };
          guest = {
            id = 4;
            name = "vlan-guest";
          };
          server = {
            id = 3;
            name = "vlan-server";
          };
          vpn = {
            id = 6;
            name = "vlan-vpn";
          };
        };
      };
    };
```

    - Bridge declarations (topology). Bridge netdevs are created by the bridge module.
      - Declares bridge netdevs (created by the bridge module). `interfaces` lists the device names (physical or VLAN names) to attach to that bridge. `stp` controls Spanning Tree Protocol if you are connecting multiple switches/bridges.
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

- Networks section:
  - This is the place to attach configuration that will be translated to systemd-networkd units (or the project-specific network wiring). It uses `match.name` to select devices and `networkConfig` for arbitrary networkd snippets (like `Bridge = "br-lan"`, `VLAN = [...]`).
  - The `type` field (seen as `static`/`unmanaged` in the example) controls whether the host assigns an address. `static` entries include `ip`, `gateway`, and `dns`. `unmanaged` means "bring the interface up but don't assign IPs". You can also use DHCP by setting `type = "dhcp"` in entries where that is supported by the module.
- VLAN -> Bridge wiring:
  - The pattern used here is: create VLAN devices under the physical interface (`interfaces` → `vlans`), then add those VLAN devices into bridges (either by listing them in `bridges.[].interfaces` or by adding a `networkConfig` that sets `Bridge = ...`).
- VM interface patterns:
  - Use glob `match.name` values such as `vm-lan-*` to automatically attach dynamically created VM tap devices to the appropriate host bridge.

```nix
  networks = {
      # assign VLAN devices to physical device (VLAN member setup)
      vlan-to-phys = {
        match = {
          name = "phys0";
        };
        networkConfig = {
          VLAN = [
          "vlan-lan"
          "vlan-iot"
          "vlan-guest"
          "vlan-server"
          "vlan-vpn"
          ];
        };
      };

      # put VLAN devices into the bridges
      vlan-br-lan = {
        match = {
          name = "vlan-lan";
        };

        networkConfig = {
            Bridge = "br-lan";
        };
      };
      vlan-br-iot = {
        match = {
          name = "vlan-iot";
        };

        networkConfig = {
          Bridge = "br-iot";
        };
      };
      vlan-br-guest = {
        match = {
          name = "vlan-guest";
        };

        networkConfig = {
          Bridge = "br-guest";
        };
      };
      vlan-br-server = {
        match = {
          name = "vlan-server";
        };

        networkConfig = {
          Bridge = "br-server";
        };
      };
      vlan-br-vpn = {
        match = {
          name = "vlan-vpn";
        };

        networkConfig = {
          Bridge = "br-vpn";
        };
      };

      # Bridges with addressing for host access
      br-lan = {
        type = "static";
        ip = "192.168.1.20/24";
        gateway = "192.168.1.1";
        dns = [ "192.168.1.1" ];

        match = {
          name = "br-lan";
        };
      };

      br-server = {
        type = "static";
        ip = "192.168.3.20/24";

        match = {
          name = "br-lan";
        };
      };

      # Bridges without addresses just to bring them up
      br-guest = {
        type = "unmanaged";
        match = {
          name = "br-guest";
        };

      };
      br-iot = {
        type = "unmanaged";
        match = {
          name = "br-iot";
        };

      };

      br-vpn = {
        type = "unmanaged";
        match = {
          name = "br-vpn";
        };
      };

      # VM interface patterns that should be bridged into guests' bridges
      vm-br-lan = {
        match = {
          name = "vm-lan-*";
        };
        networkConfig = {
          Bridge = "br-lan";
        };
      };
      vm-br-server = {
        match = {
          name = "vm-srv-*";
        };
        networkConfig = {
          Bridge = "br-server";
        };
      };
      vm-br-guest = {
        match = {
          name = "vm-gst-*";
        };

        networkConfig = {
          Bridge = "br-guest";
        };
      };
      vm-br-iot = {
        match = {
          name = "vm-iot-*";
        };

        networkConfig = {
          Bridge = "br-iot";
        };
      };

      vm-br-vpn = {
        match = {
          name = "vm-vpn-*";
        };
        networkConfig = {
          Bridge = "br-vpn";
        };
      };
    };
  };
```

## Bridging gotchas

By default the bridge module will emit a deterministic MAC for a bridge by
deriving it from the first enslaved interface's configured MAC (if that
interface has a `match.mac` configured). This ensures the bridge gets a
stable hardware address across boots which can be useful if other parts of
your configuration match by MAC.

If you prefer to control the bridge MAC explicitly, set `mac = "..."` on
the bridge declaration. Use a locally-administered unicast address (set the
second-least-significant bit of the first octet to 1).

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
