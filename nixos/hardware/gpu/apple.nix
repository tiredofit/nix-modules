{ config, inputs, lib, pkgs, ... }:
let
  device = config.host.hardware;
in
  with lib;
{
  imports = [
    inputs.apple-silicon.nixosModules.default
  ];

  config = mkIf ((device.cpu == "apple") && (device.gpu == "apple"))  {
    hardware = {
      asahi = {
        useExperimentalGPUDriver = mkDefault true;
      };
    };
  };
}
