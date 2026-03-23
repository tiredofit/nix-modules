{config, lib, pkgs, ...}:

let
  cfg = config.host.application.starship;
  tomlFormat = pkgs.formats.toml { };
  starshipConfig = "/etc/starship.toml";
  programsSet = config.programs or {};
  starshipProgram = programsSet.starship or {};
  settingsAttr = starshipProgram.settings or {};
  hasSettings = lib.isAttrs settingsAttr && (builtins.length (lib.attrNames settingsAttr) > 0);
  generatedToml = if hasSettings then tomlFormat.generate "starship.toml" settingsAttr else null;
in
  with lib;
{
  options = {
    host.application.starship = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables starship";
      };
    };
  };

  config = mkIf cfg.enable {
    environment = lib.optionalAttrs hasSettings {
      sessionVariables = {
        STARSHIP_CONFIG = starshipConfig;
      };
      variables = {
        STARSHIP_CONFIG = starshipConfig;
      };
    };

    programs = {
      bash = {
        #interactiveShellInit = ''
        #  if [[ $TERM != "dumb" ]]; then
        #    eval "$(${pkgs.starship}/bin/starship init bash --print-full-init)"
        #  fi
        #'';
      };
      zsh = {
        #interactiveShellInit = ''
        #  if [[ $TERM != "dumb" ]]; then
        #    eval "$(${pkgs.starship}/bin/starship init zsh)"
        #  fi
        #'';
      };
      starship = {
        enable = true;
      };
    };

    system.activationScripts = lib.optionalAttrs hasSettings {
      starshipToml = lib.stringAfter [ "etc" ] ''
        install -m 0644 ${generatedToml} ${starshipConfig}
      '';
    };
  };
}