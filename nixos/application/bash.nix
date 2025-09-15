{config, lib, pkgs, ...}:
let
  cfg = config.host.application.bash;
  shellAliases = {
    ".." = "cd ..";
    "..." = "cd ...";
    fuck = "sudo $(history -p !!)"; # run last command as root
    home = "cd ~";
    mkdir = "mkdir -p";
    s = "sudo systemctl";
    scdisable = "sudo systemctl disable $@";
    scenable = "sudo systemctl  disable $@";
    scstart = "sudo systemctl start $@";
    scstop = "sudo systemctl stop $@";
    sj = "sudo journalctl";
    u = "systemctl --user";
    uj = "journalctl --user";
    uscdisable = "systemctl --user disable $@";
    uscenable = "systemctl --user disable $@";
    uscstart = "systemctl --user start $@";
    uscstop = "systemctl --user stop $@";
  };
in
  with lib;
{
  options = {
    host.application.bash = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables bash";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      bashInteractive # bash shell
    ];

    programs = {
      bash = {
        completion.enable = true;
        inherit shellAliases;
        shellInit = ''
          ## History
          export HISTFILE=/$HOME/.bash_history
          shopt -s histappend
          shopt -s cmdhist
          export PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND$"\n"}history -a; history -c; history -r"
          HISTTIMEFORMAT="%Y%m%d.%H%M%S%z "
          HISTFILESIZE=2000000
          HISTSIZE=3000
          export HISTIGNORE="ls:ll:ls -alh:pwd:clear:history:ps"
          HISTCONTROL=ignoreboth

          if [ -d "/var/local/data" ] ; then
            alias vld='cd /var/local/data'
          fi

          if [ -d "/var/local/db" ] ; then
            alias vldb='cd /var/local/db'
          fi

          if [ -d "/var/local/data/_system" ] ; then
            alias vlds='cd /var/local/data/_system'
          fi

          if command -v "nmcli" &>/dev/null; then
            alias wifi_scan="nmcli device wifi rescan && nmcli device wifi list"  # rescan for network
          fi

          if command -v "curl" &>/dev/null; then
            alias derp="curl https://cht.sh/$1"                       # short and sweet command lookup
          fi

          if command -v "grep" &>/dev/null; then
            alias grep="grep --color=auto"                            # Colorize grep
          fi

          if command -v "netstat" &>/dev/null; then
              alias ports="netstat -tulanp"                             # Show Open Ports
          fi

          if command -v "tree" &>/dev/null; then
            alias tree="tree -Cs"
          fi

          if command -v "rsync" &>/dev/null; then
              alias rsync="rsync -aXxtv"                                # Better copying with Rsync
          fi

          if command -v "rg" &>/dev/null && command -v "fzf" &>/dev/null && command -v "bat" &>/dev/null; then
            function frg {
              result=$(rg --ignore-case --color=always --line-number --no-heading "$@" |
              fzf --ansi \
                  --color 'hl:-1:underline,hl+:-1:underline:reverse' \
                  --delimiter ':' \
                  --preview "bat --color=always {1} --theme='Solarized (light)' --highlight-line {2}" \
                  --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')
              file="''${result%%:*}"
              linenumber=$(echo "''${result}" | cut -d: -f2)
              if [ ! -z "$file" ]; then
                $EDITOR +"''${linenumber}" "$file"
              fi
            }
          fi

          # systemctl helpers
          if command -v "fzf" &>/dev/null; then
            _sysls() {
                # $1: --system or --user
                # $2: states, see also "systemctl list-units --state=help"
                WIDE=$1
                [ -n $2 ] && STATE="--state=$2"
                cat \
                    <(echo 'UNIT/FILE LOAD/STATE ACTIVE/PRESET SUB DESCRIPTION') \
                    <(systemctl $WIDE list-units --legend=false $STATE) \
                    <(systemctl $WIDE list-unit-files --legend=false $STATE) \
                | sed 's/●/ /' \
                | grep . \
                | column --table --table-columns-limit=5 \
                | fzf --header-lines=1 \
                      --accept-nth=1 \
                      --no-hscroll \
                      --preview="SYSTEMD_COLORS=1 systemctl $WIDE status {1}" \
                      --preview-window=down
            }

            alias sls='_sysls --system'
            alias uls='_sysls --user'
            alias sjf='sj --unit $(uls) --all --follow'
            alias ujf='uj --unit $(uls) --all --follow'

            _SYS_ALIASES=(
              sstart sstop sre
              ustart ustop ure
            )

            _SYS_CMDS=(
              's start $(sls static,disabled,failed)'
              's stop $(sls running,failed)'
              's restart $(sls)'
              'u start $(uls static,disabled,failed)'
              'u stop $(uls running,failed)'
              'u restart $(uls)'
            )

            _sysexec() {
                for ((j=0; j < ''${#_SYS_ALIASES[@]}; j++)); do
                    if [ "$1" == "''${_SYS_ALIASES[$j]}" ]; then
                      cmd=$(eval echo "''${_SYS_CMDS[$j]}") # expand service name
                      wide=''${cmd:0:1}
                      cmd="$cmd && ''${wide} status \$_ || ''${wide}j -xeu \$_"
                      eval $cmd
                      [ -n "$BASH_VERSION" ] && history -s $cmd
                      #[ -n "$ZSH_VERSION" ] && print -s $cmd
                      return
                    fi
                done
            }

            for i in ''${_SYS_ALIASES[@]}; do
              source /dev/stdin <<EOF
            $i() {
              _sysexec $i
            }
EOF
            done

          fi

          if [ -d "$HOME/.bashrc.d" ] ; then
            for script in $HOME/.bashrc.d/* ; do
                source $script
            done
          fi
          sir() {
               if [ -z $1 ] || [ -z $2 ] ; then echo "Search inside Replace: sir <find_string_named> <sring_replaced>" ; return 1 ; fi
               for file in $(rg -l $1) ; do
                    sed -i "s|$1|$2|g" "$file"
               done
          }

          far() {
            if [ -z $1 ] || [ -z $2 ] ; then echo "Rename files: far <find_file_named> <file_renamed>" ; return 1 ; fi
            for file in $(find -name "$1") ; do
                 mv "$file" $(dirname "$file")/$2
            done
          }

          # Quickly run a pkg run nixpkgs - Add a second argument to it otherwise it will simply run the command
          pkgrun () {
            if [ -n $1 ] ; then
              local pkg
              pkg=$1
              if [ "$2" != "" ] ; then
                shift
                local args
                args="$@"
              else
                args=$pkg
              fi
              nix-shell -p $pkg.out --run "$args"
            fi
          }

          resetcow() {
            process_path() {
              local path="$1"
              if [ -f "$path" ]; then
                local perms owner group
                perms=$(stat -c %a "$path")
                owner=$(stat -c %u "$path")
                group=$(stat -c %g "$path")
                touch "$path.nocow"
                chattr +c "$path.nocow"
                dd if="$path" of="$path.nocow" bs=1M 2&>/dev/null
                rm "$path"
                mv "$path.nocow" "$path"
                chmod "$perms" "$path"
                chown "$owner:$group" "$path"
                echo "Removed Copy on Write for file '$path'"
              elif [ -d "$path" ]; then
                local perms owner group
                perms=$(stat -c %a "$path")
                owner=$(stat -c %u "$path")
                group=$(stat -c %g "$path")
                mv "$path" "$path.nocowdir"
                mkdir -p "$path"
                chattr +C "$path"
                cp -aR "$path.nocowdir/"* "$path"
                cp -aR "$path.nocowdir/."* "$path" 2>/dev/null
                rm -rf "$path.nocowdir"
                chmod "$perms" "$path"
                chown "$owner:$group" "$path"
                echo "Removed Copy on Write for directory '$path'"
              else
                echo "Can't detect if '$path' is file or directory, skipping"
              fi
            }

            local target_name="$1"
            local search_dir="$2"

            if [ -z "$target_name" ]; then
              echo "Usage: resetcow <file_or_dir_name> [search_directory]"
              return 1
            fi

            if [ -z "$search_dir" ]; then
              process_path "$target_name"
            else
              find "$search_dir" -name "$target_name" | while read -r path; do
                process_path "$path"
              done
            fi
          }
        '';
      };
    };
  };
}
