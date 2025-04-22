{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.wireless;
in
  with lib;
{
  options = {
    host.hardware.wireless = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables tools for wireless";
      };
      backend = mkOption {
        default = "iwd";
        type = with types; enum [ "iwd" "wpa_supplicant" ];
        description = "The backend to use for wireless management";
      };
    };
  };

  config = mkIf cfg.enable {
    boot.extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom="CA"
    '';

    environment.systemPackages = with pkgs; [
      unstable.impala
      iw
    ];

    hardware.wirelessRegulatoryDatabase = mkDefault true;

    networking.wireless.iwd.enable = mkDefault (cfg.backend == "iwd");

    host.filesystem.impermanence.directories = mkIf ((config.host.filesystem.impermanence.enable) && (config.networking.networkmanager.enable)) [
      "/var/lib/iwd"
      "/var/lib/NetworkManager"
    ];
  };
}
