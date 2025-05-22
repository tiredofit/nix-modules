{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.documentation;
in
  with lib;
{
  options = {
    host.feature.documentation = {
      enable = mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable documentation features";
      };
      dev = {
        enable = mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable dev docs";
        };
      };
      info = {
        enable = mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable info docs";
        };
      };
      man = {
        enable = mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable man pages";
        };
        db.enable = mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable man-db";
        };
      };
      nixos = {
        enable = mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable NixOS docs";
        };
        splitBuild = mkOption {
          type = lib.types.bool;
          default = false;
          description = "Split build for NixOS docs";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    documentation = {
      enable = mkDefault true;
      dev.enable = cfg.dev.enable;
      info.enable = cfg.info.enable;
      nixos.enable = cfg.nixos.enable;
      nixos.options.splitBuild = false;
      man = {
        enable = cfg.man.enable;
        man-db.enable = cfg.man.db.enable;
      };
    };
  };
}
