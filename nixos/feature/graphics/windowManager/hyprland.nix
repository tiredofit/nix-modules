{ config, inputs, lib, pkgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
in

{
  config = mkIf (graphics.enable && graphics.windowManager.manager == "hyprland") (let
    hyprlandUWSMDesktopOverride = pkgs.runCommand "hyprland-uwsm-desktop" {} ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/hyprland.desktop <<'EOF'
[Desktop Entry]
Name=Hyprland (uwsm-managed)
Comment=An intelligent dynamic tiling Wayland compositor
Exec=uwsm start -e -D Hyprland hyprland.desktop
Type=Application
EOF
    '';
  in {
    programs = {
      hyprland = {
        enable = mkDefault true;
        package = mkDefault pkgs.hyprland;
        #portalPackage = pkgs.xdg-desktop-portal-hyprland;
        withUWSM  = mkDefault true;
        #package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      };
    };

    environment.systemPackages = mkIf config.programs.hyprland.withUWSM [
      hyprlandUWSMDesktopOverride
    ];
    system.activationScripts.hyprland-uwsm-desktop = {
      text = ''
        mkdir -p /var/lib/greetd/wayland-sessions
        cp -aT "${hyprlandUWSMDesktopOverride}/share/wayland-sessions" "/var/lib/greetd/wayland-sessions" || true
      '';
    };
  });
}
