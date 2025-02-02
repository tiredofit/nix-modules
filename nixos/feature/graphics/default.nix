{config, lib, pkgs, ...}:
  with lib;
{
  imports = [
    ./backend
    ./displayManager
    ./windowManager
  ];

  options = {
    host.feature.graphics = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables Graphics Support";
      };
      acceleration = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables graphics acceleration";
      };
      backend = mkOption {
        type = types.enum ["x" "wayland" null];
        default = null;
        description = "Backend of displayManager";
      };
    };
  };

  config = {
    hardware = {
      graphics = mkIf ((config.host.feature.graphics.enable) && (config.host.feature.graphics.acceleration)) {
        #package = pkgs.unstable.mesa.drivers;
        enable = true;
        enable32Bit = true;
      };
    };

    environment = {
      systemPackages = with pkgs; mkIf (config.host.feature.graphics.enable) [
        libva
        libva-utils
        vulkan-loader
        vulkan-tools
        vulkan-validation-layers
      ];
    };
  };
}
