{ config, inputs, outputs, lib, pkgs, nixpkgsBranch, ... }:
let
  cfg = config.host.feature.home-manager;
in
  with lib;
{
  options = {
    host.feature.home-manager = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Home manager to provide isolated home configurations per user";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      home-manager
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs outputs;
        inherit nixpkgsBranch;
      };
    };
  };
}