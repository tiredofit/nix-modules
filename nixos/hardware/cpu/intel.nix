{ config, lib, pkgs, ... }:
let
  device = config.host.hardware ;
in
  with lib;
{
  config = mkIf (device.cpu == "intel" || device.cpu == "vm-intel") {

    environment.systemPackages = with pkgs; [
      intel-gpu-tools
    ];

    # Enable qemu-guest services when running in a VM (vm-intel)
    services.qemuGuest.enable = mkDefault (device.cpu == "vm-intel");

    hardware.cpu.intel.updateMicrocode = true;

    host.feature.boot.kernel = {
      modules = [
        "kvm-intel"
      ];
      parameters = [
        "enable_gvt=1"
        "i915.fastboot=1"
      ];
    };

    nixpkgs = {
      hostPlatform = "x86_64-linux";
    };
  };
}
