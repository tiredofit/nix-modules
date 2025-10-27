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
        default = "wpa_supplicant";
        type = with types; enum [ "iwd" "wpa_supplicant" ];
        description = "The backend to use for wireless management";
      };
      regdom = mkOption {
        type = types.nullOr types.str;
        default = "CA";
        description = "Regulatory domain (ISO 3166-1 alpha-2).";
      };
    };
  };

  config = mkIf cfg.enable {
    boot.extraModprobeConfig = mkIf (cfg.regdom != null) ''
      options cfg80211 ieee80211_regdom="${cfg.regdom}"
    '';

    environment.systemPackages = with pkgs; [
      unstable.iw
    ] ++ lib.optionals (cfg.backend == "iwd") [
      unstable.impala
      unstable.iwd
    ];

    hardware.wirelessRegulatoryDatabase = mkDefault true;

    host.filesystem.impermanence.directories = mkIf (config.host.filesystem.impermanence.enable) (
      [
      ] ++
      (if (cfg.backend == "iwd") then [
        "/var/lib/iwd"
      ] else [])
    );

    networking = {
      wireless = mkIf ((config.host.network.manager != "networkmanager") && (config.host.network.manager != "both")) {
        iwd = mkIf (cfg.backend == "iwd") {
          enable = mkDefault true;
          package = mkDefault pkgs.unstable.iwd;
        };
        enable = mkDefault (cfg.backend == "wpa_supplicant");
      };
    };
  };
}

## Declarative TODO
# ## Only read these secrets if the secret exists
    #"wireless/${profile}.yml" = lib.mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/wireless/${profile}.yml") {}
    #  sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/profile.yml";
    #  format = "yaml";
    #};

    # https://search.nixos.org/options?channel=unstable&show=networking.networkmanager.ensureProfiles.secrets.entries&query=ensureprofiles
    # https://search.nixos.org/options?channel=unstable&show=networking.networkmanager.ensureProfiles.profiles&query=ensureprofiles
## Network Manager
#      profile_name = {
#        connection = {
#          id = "nmconnectionid";
#          type = "wifi";
#        };
#        wifi = {
#          mode = "infrastructure";
#          ssid = "randomssid";
#        };
#        wifi-security = {
#          auth-alg = "open";
#          key-mgmt = "wpa-psk";
#          psk = "havetoputasecretinhere";
#        };
#      };

## NixOS wireless configuration examples
## content of /run/secrets/wireless.conf
#psk_home=mypassword
#psk_other=123456
#pass_work=myworkpassword
#
## wireless-related configuration
#networking.wireless.secretsFile = "/run/secrets/wireless.conf";
#networking.wireless.networks = {
#  home.pskRaw =  "ext:psk_home";
#  other.pskRaw = "ext:psk_other";
#  work.auth = ''
#    eap=PEAP
#    identity="my-user@example.com"
#    password=ext:pass_work
#  '';
#
#  { echelon = {                   # SSID with no spaces or special characters
#    psk = "abcdefgh";           # (password will be written to /nix/store!)
#  };
#
#  echelon = {                   # safe version of the above: read PSK from the
#    pskRaw = "ext:psk_echelon"; # variable psk_echelon, defined in secretsFile,
#  };                            # this won't leak into /nix/store
#
#  "echelon's AP" = {            # SSID with spaces and/or special characters
#     psk = "ijklmnop";          # (password will be written to /nix/store!)
#  };
#
#  "free.wifi" = {};             # Public wireless network
