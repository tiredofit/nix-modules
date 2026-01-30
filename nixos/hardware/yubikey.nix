{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.yubikey;
in
  with lib;
{
  options = {
    host.hardware.yubikey = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Yubikey support";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      #yubikey-manager
      #yubikey-manager-qt
      yubikey-personalization
      yubico-piv-tool
      yubioath-flutter
    ];

    hardware.gpgSmartcards.enable = mkDefault true;

    services = {
      pcscd.enable = mkDefault true;
      udev.packages = [pkgs.yubikey-personalization];
    };

    programs = {
      ssh.startAgent = mkDefault false;
      gnupg.agent = {
        enable = mkDefault true;
        enableSSHSupport = mkDefault true;
      };
    };
  };
}
