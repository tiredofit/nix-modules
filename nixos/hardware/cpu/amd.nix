{ config, lib, ... }:
with lib;
let
  kver = config.boot.kernelPackages.kernel.version;
  device = config.host.hardware ;
in {
  config = mkIf (device.cpu == "amd" || device.cpu == "vm-amd") {
   boot.blacklistedKernelModules = mkIf (device.cpu == "amd") [ "k10temp" ];
   boot.extraModulePackages = mkIf (device.cpu == "amd") [ config.boot.kernelPackages.zenpower ];
   boot.kernelModules = mkIf (device.cpu == "amd") [ "zenpower" ];

   hardware.cpu.amd.updateMicrocode = true;

    host.feature.boot.kernel = {
      modules = [
        "kvm-amd"
      ];
      parameters = [
        "amd_pstate=active"
      ];
    };

    nixpkgs = {
      hostPlatform = "x86_64-linux";
    };

    services.qemuGuest.enable = mkDefault (device.cpu == "vm-amd");
  };
}
