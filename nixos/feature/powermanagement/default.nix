{lib, ...}:
with lib;
{
  imports = [
    ./battery.nix
    ./cpu.nix
    ./disks.nix
    ./powertop.nix
    ./thermal.nix
    ./tlp.nix
    ./undervolt.nix
  ];
}
