{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.fonts;
  graphics = config.host.feature.graphics;
in
  with lib;
{
  options = {
    host.feature.fonts = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Fonts";
      };
    };
  };

  config = mkIf cfg.enable {
    fonts = mkIf graphics.enable {
      enableDefaultPackages = false;
      fontDir.enable = true;
      packages = with pkgs; [
        dejavu_fonts
        liberation_ttf
        nerd-fonts.hack
        nerd-fonts.noto
        nerd-fonts.ubuntu
        noto-fonts
        noto-fonts-color-emoji
        open-sans
        roboto
      ] ++ (
        if (lib.versionAtLeast lib.version "25.11pre") then [
          ubuntu-classic
        ] else [
          ubuntu_font_family
        ]
      );

      fontconfig = mkIf graphics.enable {
        enable = mkDefault true;
        antialias = mkDefault true;
        cache32Bit = mkDefault false;
        hinting = {
          enable = mkDefault true;
          autohint = mkDefault false;
        };
        defaultFonts = {
          serif = [
            "Noto Serif NF"
            "Noto Serif"
            "Liberation Serif"
            "DejaVu Serif"
          ];
          sansSerif = [
            "Noto Sans NF"
            "Noto Sans"
            "Roboto"
            "Open Sans"
            "Liberation Sans"
            "DejaVu Sans"
          ];
          monospace = [
            "Hack Nerd Font"
            "NotoSansM Nerd Font Mono"
            "Noto Sans Mono"
            "DejaVu Sans Mono"
            "Liberation Mono"
          ];
          emoji = [
            "Noto Color Emoji"
          ];
        };
      };
    };
  };
}
