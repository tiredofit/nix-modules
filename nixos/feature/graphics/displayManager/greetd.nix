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
        gdm = {
          enable = mkForce false;
        };
        sddm = {
          enable = mkForce false;
        };
      };
      greetd = {
        enable = mkDefault true;
        settings = mkDefault {
          default_session = {
            command = mkDefault (
              let
                greeter = config.host.feature.graphics.displayManager.greetd.greeter.name;
                gtkgreetBin = "${pkgs.gtkgreet}/bin/gtkgreet";
                regreetBin = "${pkgs.regreet}/bin/regreet";
                tuigreetBin = "${pkgs.tuigreet}/bin/tuigreet";
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
          gdm = {
            enable = mkForce false;
          };
          lightdm = {
            enable = mkForce false;
          };
          startx.enable = config.services.xserver.enable;
        };
      };
    };
  };
}