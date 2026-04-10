{ config, lib, pkgs, ... }:
with lib;

{
  options = {
    host.feature.graphics.displayManager.greetd = {
      greeter = {
        name = mkOption {
          type = types.enum ["gtk" "regreet" "tuigreet"];
          default = "tuigreet";
          description = "GreetD greeter to use";
        };
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Extra configuration that should be put in the greeter configuration file";
      };
    };
  };

  config = mkIf (config.host.feature.graphics.displayManager.manager == "greetd") {
    security.pam.services.greetd.enableGnomeKeyring = true;

    services = {
      displayManager = {
        sddm.enable = mkForce false;
        gdm.enable = mkForce false;
      };
      greetd = {
        enable = mkDefault true;
        settings = {
          default_session = {
              command = mkDefault (
              let
                greeter = config.host.feature.graphics.displayManager.greetd.greeter.name;
                gtkgreetBin = "${pkgs.gtkgreet}/bin/gtkgreet";
                regreetBin = "${pkgs.regreet}/bin/regreet";
                tuigreetBin = "${pkgs.tuigreet}/bin/tuigreet";
                desktops = config.services.displayManager.sessionData.desktops;
                # writable directory where greetd/tuigreet can store/overwrite session files
                sessionsDir = "/var/lib/greetd/wayland-sessions";
                tuigreetSessionsFlag = if config.host.feature.graphics.backend == "wayland" then
                  " --sessions " + sessionsDir + " "
                else
                  "";              in
                if greeter == "tuigreet" then
                  "${tuigreetBin} --time --remember --remember-user-session" + tuigreetSessionsFlag
                else if greeter == "gtk" then gtkgreetBin
                else if greeter == "regreet" then regreetBin
                else tuigreetBin
            );
            #user = "greeter";
          };
        };
      };
      xserver.displayManager = {
        lightdm.enable = mkForce false;
        startx.enable = config.services.xserver.enable;
      };
    };
    system.activationScripts.greetd-sessions = {
      text = ''
        mkdir -p /var/lib/greetd/wayland-sessions
        if [ -d "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions" ]; then
          cp -aT "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions" "/var/lib/greetd/wayland-sessions"
        fi
      '';
    };
  };
}