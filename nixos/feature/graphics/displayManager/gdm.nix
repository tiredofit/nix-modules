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
  imports = lib.optionals (lib.versionOlder lib.version "25.11pre") [
    (lib.mkAliasOptionModule ["services" "displayManager" "gdm" "enable"] ["services" "xserver" "displayManager" "gdm" "enable" ])
  ];

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
