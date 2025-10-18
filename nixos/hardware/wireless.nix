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
      options cfg80211 ieee80211_regdom="US"
    '';

    environment.systemPackages = with pkgs; [
      unstable.impala
      iw
    ];

    hardware.wirelessRegulatoryDatabase = mkDefault true;

    host.filesystem.impermanence.directories = mkIf ((config.host.filesystem.impermanence.enable) && (cfg.backend == "iwd")) [
      "/var/lib/iwd"
    ];

    networking = {
      wireless.enable = if cfg.backend == "wpa_supplicant"
        then lib.mkDefault true
        else lib.mkForce false;

      wireless.iwd.enable = lib.mkDefault (cfg.backend == "iwd");

      networkmanager.wifi.backend = lib.mkDefault (if cfg.backend == "iwd" then "iwd" else "wpa_supplicant");
    };
  };
}
