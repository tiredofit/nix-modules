{ config, inputs, lib, pkgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
in

{
  config = mkIf (graphics.enable && graphics.windowManager.manager == "hyprland") {
    programs = {
      hyprland = {
        enable = mkDefault true;
        package = pkgs.hyprland;
        #portalPackage = pkgs.xdg-desktop-portal-hyprland;
        withUWSM  = true;
        #package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      };
    };

    #xdg.portal = {
    #  enable = true;
    #  xdgOpenUsePortal = true;
    #  config.common = {
    #    "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    #    "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
    #    #"org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
    #    #"org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    #    #"org.freedesktop.portal.FileChooser" = [ "xdg-desktop-portal-gtk" ];
    #  };
    #  extraPortals = with pkgs; [
    #    xdg-desktop-portal-gtk
    #    xdg-desktop-portal-wlr
    #    xdg-desktop-portal-hyprland
    #    #xdg-desktop-portal-shana
    #  ];
    #};
  };
}
