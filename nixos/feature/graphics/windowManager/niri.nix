{ config, inputs, lib, pkgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
in
{
  config = mkIf (graphics.enable && builtins.elem "niri" graphics.windowManager.manager) {
    programs = {
      niri = {
        enable = mkDefault true;
        package = mkDefault pkgs.niri;
      };
    };

    environment.systemPackages = with pkgs; [
      niriswitcher
      nirius
      niri
    ];
  };
}
