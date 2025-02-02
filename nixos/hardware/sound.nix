{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.sound;

  script_sound-tool = pkgs.writeShellScriptBin "sound-tool" ''
    echo "Hello World"
  '';
in
  with lib;
{
  options = {
    host.hardware.sound = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Sound";
      };
      server = mkOption {
        type = types.str;
        default = "pipewire";
        description = "Which sound server (pulseaudio/pipewire)";
      };
    };
  };

  imports = lib.optionals (lib.versionOlder lib.version "25.05pre") [
    (lib.mkAliasOptionModule ["services" "pulseaudio" "enable"] ["hardware" "pulseaudio" "enable"])
  ];

  config = {
    environment = {
      systemPackages = mkIf cfg.enable [
        script_sound-tool
      ];
    };

    services.pulseaudio = lib.mkMerge [
      (lib.mkIf (cfg.enable && cfg.server == "pulseaudio") {
        enable = mkForce true;
      })

      (lib.mkIf (cfg.enable && cfg.server == "pipewire") {
        enable = mkForce false;
      })

     (lib.mkIf (! cfg.enable ) {
        enable = mkForce false;
      })
    ];

    services.pipewire = mkIf (cfg.enable && cfg.server == "pipewire") {
      enable = mkForce true;
      alsa = {
        enable = mkDefault true;
        support32Bit = mkDefault true;
      };
      pulse.enable = mkDefault true;
      wireplumber = {
        enable = mkDefault true;
        configPackages = [
        ];
      };
    };

    security.rtkit = mkIf (cfg.enable && cfg.server == "pipewire") {
      enable = mkDefault true;
    };

    host.filesystem.impermanence.directories = mkIf (cfg.enable && cfg.server == "pipewire" && config.host.filesystem.impermanence.enable) [
      "/var/lib/pipewire"
    ];
  };
}
