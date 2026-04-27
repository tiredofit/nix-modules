{ config, lib, ... }:
with lib;
let
  device = config.host.hardware ;
in {
  config = mkIf (device.gpu == "intel" || device.gpu == "hybrid-nvidia" )  {

    boot.initrd.kernelModules = ["i915"];
    services.xserver.videoDrivers = ["modesetting"];

    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
    };

    hardware.graphics = {
      extraPackages = with pkgs; [
        intel-compute-runtime
        intel-media-driver
        libvdpau-va-gl
        vaapiIntel
        vaapiVdpau
      ];
    };

    environment.variables = mkIf (config.hardware.graphics.enable && device.gpu != "hybrid-nvidia") {
      VDPAU_DRIVER = "va_gl";
    };
  };
}