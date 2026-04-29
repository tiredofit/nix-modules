{ config, inputs, lib, pkgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
in
{
  config = mkIf (graphics.enable && builtins.elem "cosmic" graphics.windowManager.manager) {
    services.desktopManager.cosmic.enable = true;
    environment.systemPackages = [
    ];
    services.avahi.enable = mkForce false;
  };
}
