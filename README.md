#  Nix Modules

Here are my [NixOS](https://nixos.org/) modules.

I'm using this for consistent configuration and portability from machine to machine with a small amount of changes (usually disks, partitions, or hardware changes).

They need to be imported as an input into your systems configuration. You can see how I do it with my own [NixOS Configurations](https://github.com/tiredofit/nixos-config)

## Tree Structure
- `nixos`: Modules that are specific to this implementation and allow for toggled configuration
  - `application`: Applications accessible to all users of system
  - `container`: Containers using some sort of OCI container engine
  - `features`: Features such as virtualization, gaming, cross compilation
  - `filesystem`: Encryption, impermanence, BTRFS options
  - `hardware`: Bluetooth, Printing, Sound, Wireless
  - `network`: Firewalls and VPNs
  - `service`: Miscellanious daemons

### Configuring a system

Features are toggleable via the `host` configuration options. Have a look insie the `modules/nixos` folder for options available.

For example to have a base AMD system using with an integrated GPU using BTRFS as a file system that allowed SSH, Docker, and a hardware webcam it would be configured as such:

```
  host = {
    hardware = {
      cpu = "amd";
      graphics = {
        acceleration = true;
        displayServer = "x";
        gpu = "integrated-amd";
      };
      webcam.enable = true;
    };
    network = {
      hostname = "samplehostname" ;
      domainname = "tiredofit.ca" ;
    };
    role = server;
  };
```

This very much relies on the `nixos/roles` folder and sets defaults per role, which can be overridden in each hosts unique configuration.

# License

Do you what you'd like and I hope that this inspires you for your own configurations as many others have myself attribution would be appreciated.
