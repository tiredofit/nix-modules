{config, lib, pkgs, ...}:
with lib;
{
  imports = [
    #./apple.nix
    ./ampere.nix
    ./amd.nix
    ./intel.nix
  ];

  options = {
    host.hardware = {
      cpu = mkOption {
        type = types.enum ["amd" "ampere" "apple" "intel" "vm-amd" "vm-intel" null];
        default = null;
        description = "Type of CPU";
      };
    };
  };
}