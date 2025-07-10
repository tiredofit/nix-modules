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

  imports = lib.optionals (lib.versionOlder lib.version "25.11pre") [
    (lib.mkAliasOptionModule ["services" "displayManager" "gdm" "enable"] ["services" "xserver" "displayManager" "gdm" "enable" ])
  ];

  config = mkIf (config.host.feature.graphics.displayManager.manager == "greetd") {
    security.pam.services.greetd.enableGnomeKeyring = true;

    services = {
      displayManager = {
        sddm = {
          enable = mkForce false;
        };
      };
      greetd = {
        enable = mkDefault true;
        settings = {
          default_session = {
            command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time";
            #user = "greeter";
          };
        };
        ## TODO - Finish this later
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