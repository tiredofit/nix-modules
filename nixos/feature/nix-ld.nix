{ config, lib, pkgs, ... }:

let
  cfg = config.host.feature."nix-ld";
in
with lib;
{
  options = {
    host.feature."nix-ld" = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Nix-based dynamic library compatibility helpers (nix-ld).";
      };
      libraries = mkOption {
        type = with types; listOf package;
        default = with pkgs; [
          stdenv.cc.cc.lib
          zlib
          openssl
          curl
          glibc
        ];
        description = "List of libraries to expose when using nix-ld.";
      };
    };
  };

  config = mkIf cfg.enable {
    programs = {
      "nix-ld" = {
        enable = mkDefault true;
        libraries = mkDefault cfg.libraries;
      };
    };

    environment.systemPackages = with pkgs; [
      nix-ld
    ];
  };
}
