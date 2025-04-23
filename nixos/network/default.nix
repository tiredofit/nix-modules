{lib, ...}:

with lib;

{
  imports = [
    ./bridge.nix
    ./firewall
    ./domainname.nix
    ./hostname.nix
    ./manager.nix
    ./vpn
    ./wired.nix
  ];
}