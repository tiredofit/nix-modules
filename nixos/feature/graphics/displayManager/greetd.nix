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
        sddm = {
          enable = mkForce false;
        };
      }
      // (lib.optionalAttrs (lib.versionAtLeast lib.version "25.11pre") {
        gdm = {
          enable = mkForce false;
        };
      });
      greetd = {
        enable = mkDefault true;
        settings = {
          default_session = {
            command = mkDefault (
              let
                greeter = config.host.feature.graphics.displayManager.greetd.greeter.name;
                gtkgreetBin = if lib.versionAtLeast lib.version "25.11pre" then "${pkgs.gtkgreet}/bin/gtkgreet" else "${pkgs.greetd.gtkgreet}/bin/gtkgreet";
                regreetBin = if lib.versionAtLeast lib.version "25.11pre" then "${pkgs.regreet}/bin/regreet" else "${pkgs.greetd.regreet}/bin/regreet";
                tuigreetBin = if lib.versionAtLeast lib.version "25.11pre" then "${pkgs.tuigreet}/bin/tuigreet" else "${pkgs.greetd.tuigreet}/bin/tuigreet";
              in
                if greeter == "tuigreet" then "${tuigreetBin} --time"
                else if greeter == "gtk" then gtkgreetBin
                else if greeter == "regreet" then regreetBin
                else tuigreetBin
            );
            #user = "greeter";
          };
        };
      };

      xserver = {
        displayManager = {
          lightdm = {
            enable = mkForce false;
          };
          startx.enable = config.services.xserver.enable;
        }
        // (lib.optionalAttrs (!lib.versionAtLeast lib.version "25.11pre") {
          gdm = {
            enable = mkForce false;
          };
        });
      };
    };
  };
}