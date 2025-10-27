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
