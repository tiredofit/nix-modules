{ config, lib, pkgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
in

{
  config = mkIf (graphics.enable && graphics.displayManager.manager == "gdm") {
    services.displayManager.gdm.enable = mkDefault true;
  };
}
