{ config, inputs, lib, pkgs, ... }:
let
  device = config.host.hardware;
  isApple = (device.cpu or null) == "apple";
in
with lib;
{
  imports = [
    inputs.apple-silicon.nixosModules.default
  ];

  config = mkMerge [
    { hardware.asahi.enable = mkDefault false; }
    (mkIf isApple {
      hardware.asahi.enable = mkForce true;
      boot = {
        loader.efi.canTouchEfiVariables = mkForce false;
        loader.systemd-boot.enable = mkForce true;
      };
      hardware = {
        enableRedistributableFirmware = mkDefault true;
        asahi = {
          setupAsahiSound = mkForce false;
          peripheralFirmwareDirectory = "${inputs.asahi-firmware}/m1_mini";
        };
      };
      environment.systemPackages = with pkgs; [
        asahi-bless
        asahi-fwextract
      ];
      nixpkgs = {
        hostPlatform = "aarch64-linux";
        overlays = [
          inputs.apple-silicon.overlays.default
        ];
      };
    })
  ];
}
