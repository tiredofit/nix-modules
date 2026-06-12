{config, lib, pkgs, ...}:
let
  cfg = config.host.application.zsh;
in
  with lib;
{
  options = {
    host.application.zsh = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables zsh";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      zsh
      zsh-powerlevel10k
    ];

    environment.etc."zsh/p10k.zsh".source = ./zsh/p10k.zsh;

    programs = {
      zsh = {
        enable = true;
        enableCompletion = mkDefault true;
        autosuggestions.enable = mkDefault true;
        syntaxHighlighting.enable = mkDefault true;
        enableBashCompletion = true;
        histSize = 10000;
        shellAliases = {
          ".." = "cd ..";
          "..." = "cd ../..";
          fuck = "sudo $(fc -ln -1)";
          home = "cd ~";
          mkdir = "mkdir -p";
          s = "sudo systemctl";
          scdisable = "sudo systemctl disable";
          scenable = "sudo systemctl enable";
          screstart = "sudo systemctl restart";
          scstart = "sudo systemctl start";
          scstatus = "sudo systemctl status";
          scstop = "sudo systemctl stop";
          sj = "sudo journalctl";
          u = "systemctl --user";
          uj = "journalctl --user";
          uscdisable = "systemctl --user disable";
          uscenable = "systemctl --user enable";
          uscrestart = "systemctl --user restart";
          uscstart = "systemctl --user start";
          uscstatus = "systemctl --user status";
          uscstop = "systemctl --user stop";
        };
        setOptions = [
          "AUTO_CD"
        ];
        interactiveShellInit = ''
          ## History
          export HISTFILE=''${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
          mkdir -p "$(dirname "$HISTFILE")"
          HISTSIZE=10000
          SAVEHIST=2000000
          setopt INC_APPEND_HISTORY
          setopt SHARE_HISTORY
          setopt HIST_IGNORE_DUPS
          setopt HIST_REDUCE_BLANKS

          ## Directory shortcuts
          if [ -d "$HOME/src" ]; then alias src="cd $HOME/src"; fi

          ## Colorized file output
          colorize() {
            if [ -t 1 ]; then
              if command -v bat >/dev/null 2>&1; then
                bat --paging=never "$@"
              else
                cat "$@"
              fi
            else
              cat "$@"
            fi
          }

          ## Convert YYYYMMDD or date string to days since epoch
          days_from_epoch() {
            local input_date="$1"
            if [[ "$input_date" =~ ^[0-9]{8}$ ]]; then
              input_date="''${input_date:0:4}-''${input_date:4:2}-''${input_date:6:2}"
            fi
            echo $(( $(date -d "$input_date" +%s) / 86400 ))
          }

          ## Fetch command cheatsheet from cht.sh
          derp() {
            if command -v curl >/dev/null 2>&1; then
              curl "https://cht.sh/$1"
            else
              echo "curl not available"
              return 1
            fi
          }

          ## Rename files matching a pattern: far <pattern> <new_name>
          far() {
            if [ -z "$1" ] || [ -z "$2" ]; then
              echo "Rename files: far <find_file_named> <file_renamed>"
              return 1
            fi
            for file in $(find -name "$1"); do
              mv "$file" "$(dirname "$file")/$2"
            done
          }

          ## Search defined aliases
          findalias() {
            if [ -z "$1" ]; then
              alias
              return
            fi
            if command -v rg >/dev/null 2>&1; then
              alias | rg -i -- "$@"
            else
              alias | grep -i -- "$@" || true
            fi
          }

          ## Colorized grep
          grep() {
            command grep --color=auto "$@"
          }

          ## Colorized man pages
          man() {
            LESS_TERMCAP_md=$'\e[01;31m' \
            LESS_TERMCAP_me=$'\e[0m' \
            LESS_TERMCAP_se=$'\e[0m' \
            LESS_TERMCAP_so=$'\e[01;44;33m' \
            LESS_TERMCAP_ue=$'\e[0m' \
            LESS_TERMCAP_us=$'\e[01;32m' \
            command man "$@"
          }

          ## Show open network ports
          ports() {
            if command -v netstat >/dev/null 2>&1; then
              netstat -tulanp "$@"
            else
              ss -tulanp "$@"
            fi
          }

          ## Touch file with timestamp from a date: timestamp date <file> <date>
          timestamp() {
            case "''${1,,}" in
              date )
                local f="$2"
                local d="$3"
                touch -t "$(date -d "$d" +%Y%m%d)$(date -r "$f" +%H%M.%S)" "$f"
              ;;
            esac
          }

          ## tree with options
          tree() {
            if command -v tree >/dev/null 2>&1; then
              command tree -Cs "$@"
            else
              echo "tree not available"
              return 1
            fi
          }

          ## Weather via wttr.in
          weather() {
            if command -v curl >/dev/null 2>&1; then
              curl -sSL "https://wttr.in?F"
            else
              echo "curl not available"
              return 1
            fi
          }

          ## cd to /var/local/data
          vld() {
            if [ -d "/var/local/data" ]; then
              cd /var/local/data
            else
              echo "No /var/local/data"
              return 1
            fi
          }

          ## cd to /var/local/db
          vldb() {
            if [ -d "/var/local/db" ]; then
              cd /var/local/db
            else
              echo "No /var/local/db"
              return 1
            fi
          }

          ## cd to /var/local/data/_system
          vlds() {
            if [ -d "/var/local/data/_system" ]; then
              cd /var/local/data/_system
            else
              echo "No /var/local/data/_system"
              return 1
            fi
          }

          ## Wifi scan (requires nmcli)
          if command -v "nmcli" >/dev/null 2>&1; then
            wifi_scan() {
              nmcli device wifi rescan && nmcli device wifi list
            }
          fi

          ## Ripgrep + fzf + bat interactive search
          if command -v "rg" >/dev/null 2>&1 && command -v "fzf" >/dev/null 2>&1 && command -v "bat" >/dev/null 2>&1; then
            frg() {
              local result file linenumber
              result=$(rg --ignore-case --color=always --line-number --no-heading "$@" | \
                fzf --ansi \
                    --color 'hl:-1:underline,hl+:-1:underline:reverse' \
                    --delimiter ':' \
                    --preview "bat --color=always {1} --theme='Solarized (light)' --highlight-line {2}" \
                    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')
              file=$(printf "%s" "$result" | cut -d: -f1)
              linenumber=$(printf "%s" "$result" | cut -d: -f2)
              if [ -n "$file" ]; then
                ''${EDITOR:-vi} +"$linenumber" "$file"
              fi
            }
          fi

          # simple systemctl helpers using fzf
          if command -v "fzf" >/dev/null 2>&1; then
            _svc_select() {
              local mode="$1"
              local unit
              unit=$(systemctl $mode list-units --no-legend --all | awk '{print $1"\t"$2"\t"$3"\t"$4}' | \
                fzf --no-hscroll --preview "SYSTEMD_COLORS=1 systemctl $mode status {1}")
              printf "%s" "$unit" | awk '{print $1}'
            }

            sstart()  { local unit=$(_svc_select --system);  [ -n "$unit" ] && sudo systemctl start   "$unit"; }
            sstop()   { local unit=$(_svc_select --system);  [ -n "$unit" ] && sudo systemctl stop    "$unit"; }
            srestart(){ local unit=$(_svc_select --system);  [ -n "$unit" ] && sudo systemctl restart "$unit"; }
            ustart()  { local unit=$(_svc_select --user);    [ -n "$unit" ] && systemctl --user start   "$unit"; }
            ustop()   { local unit=$(_svc_select --user);    [ -n "$unit" ] && systemctl --user stop    "$unit"; }
            urestart(){ local unit=$(_svc_select --user);    [ -n "$unit" ] && systemctl --user restart "$unit"; }
          fi

          if [ -d "$HOME/.zshrc.d" ] ; then
            for script in $HOME/.zshrc.d/* ; do
                source $script
            done
          fi

          ## Search and replace inside files: sir <find> <replace>
          sir() {
            if [ -z "$1" ] || [ -z "$2" ]; then
              echo "Search inside Replace: sir <find_string> <replace_string>"
              return 1
            fi
            for file in $(rg -l "$1"); do
              sed -i "s|$1|$2|g" "$file"
            done
          }

          ## Run a nix-shell package one-shot: pkgrun <pkg> [cmd]
          pkgrun() {
            if [ -n "$1" ]; then
              local pkg=$1
              local args
              if [ -n "$2" ]; then
                shift
                args="$*"
              else
                args=$pkg
              fi
              nix-shell -p $pkg.out --run "$args"
            fi
          }

          ## Remove Copy-on-Write attribute from file or directory
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
                dd if="$path" of="$path.nocow" bs=1M 2>/dev/null
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

          ## Load powerlevel10k prompt
          _p10k_user_cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.p10k.zsh"
          if [[ ! -f "$_p10k_user_cfg" && ! -f "$HOME/.p10k.zsh" ]]; then
            source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
            [[ -f /etc/zsh/p10k.zsh ]] && source /etc/zsh/p10k.zsh
          fi
          unset _p10k_user_cfg
        '';
      };
    };
  };
}
