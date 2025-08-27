{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.lid;
in
  with lib;
{
  options = {
    host.hardware.lid = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Lid (typically in laptop)";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernelModules = [
        "acpi_call"
      ];
    };

    environment.systemPackages = with pkgs; [
      acpi
    ];

    services = {
      acpid = {
        enable = mkDefault true;
        lidEventCommands =
          ''
            export PATH=$PATH:/run/current-system/sw/bin

            lid_state=$(cat /proc/acpi/button/lid/LID0/state | awk '{print $NF}')
            if [ $lid_state = "closed" ]; then
                systemctl suspend
            fi
          '';

        powerEventCommands =
          ''
            systemctl suspend
          '';
      };

      logind =
        if lib.versionAtLeast lib.version "25.11pre" then {
          lidSwitchExternalPower = mkDefault "ignore";
          lidSwitchDocked = mkDefault "ignore";
          lidSwitch = mkDefault "suspend";
          settings.Login = {
            HandlePowerKey = "ignore";
          };
        } else {
          lidSwitchExternalPower = mkDefault "ignore";
          lidSwitchDocked = mkDefault "ignore";
          lidSwitch = mkDefault "suspend";
          extraConfig = ''
            HandlePowerKey=ignore
          '';
        };
    };
  };
}
