{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.console;
in
  with lib;
{
  options = {
    host.feature.console = {
      earlySetup = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables early console setup";
      };
      font = mkOption {
        default = "ter-116n";
        type = with types; str;
        description = "Sets the console font";
      };
      keymap = mkOption {
        default = "us";
        type = with types; str;
        description = "Sets the console keymap";
      };
      terminfo = {
        alacritty = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enables Alacritty terminal support";
          };
        };
        foot = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enables Foot terminal support";
          };
        };
        ghostty = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enables GhostTTY terminal support";
          };
        };
        kitty = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enables KiTTY terminal support";
          };
        };
        wezterm = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enables WezTerm terminal support";
          };
        };
      };
    };
  };

  config = {
    console = {
      earlySetup = cfg.earlySetup;
      font = cfg.font;
      keyMap = cfg.keymap;
      packages = [ pkgs.terminus_font ];
    };

    environment.systemPackages = with pkgs; [
    ]
    ++ lib.optionals cfg.terminfo.alacritty.enable [
      alacritty.terminfo
    ]
    ++ lib.optionals cfg.terminfo.foot.enable [
      foot.terminfo
    ]
    ++ lib.optionals cfg.terminfo.ghostty.enable [
      ghostty.terminfo
    ]
    ++ lib.optionals cfg.terminfo.kitty.enable [
      kitty.terminfo
    ]
    ++ lib.optionals cfg.terminfo.wezterm.enable [
      wezterm.terminfo
    ];
  };
}