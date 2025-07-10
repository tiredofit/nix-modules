{ config, lib, pkgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
  wayland =
    if (graphics.backend == "wayland")
    then true
    else false;
in

{
  config = mkIf (graphics.enable && graphics.displayManager.manager == "gdm") {
    services = {
      xserver = {
        displayManager = {
          gdm = {
            enable = mkDefault true;
            wayland = mkDefault wayland;
          };
        };
      };
    };
  };
}
