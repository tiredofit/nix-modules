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
    ];

    programs = {
      zsh = {
        enable = true;
        enableCompletion = mkDefault true;
        autosuggestions.enable = mkDefault true;
        syntaxHighlighting.enable = mkDefault true;
        enableBashCompletion = true;
        histSize = 10000;
        shellAliases = {
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
        setOptions = [
          "AUTO_CD"
        ];
        interactiveShellInit = ''
          ## History (zsh)
          export HISTFILE=$HOME/.zsh_history
          HISTSIZE=10000
          SAVEHIST=2000000
          setopt INC_APPEND_HISTORY
          setopt SHARE_HISTORY
          setopt HIST_IGNORE_DUPS
          setopt HIST_REDUCE_BLANKS
          export HIST_IGNORE_PATTERN='(^ls$|^ll$|^ls -alh$|^pwd$|^clear$|^history$|^ps$)'

          if [ -d "/var/local/data" ] ; then
            alias vld='cd /var/local/data'
          fi

          if [ -d "/var/local/db" ] ; then
            alias vldb='cd /var/local/db'
          fi

          if [ -d "/var/local/data/_system" ] ; then
            alias vlds='cd /var/local/data/_system'
          fi

          if command -v "nmcli" >/dev/null 2>&1; then
            alias wifi_scan="nmcli device wifi rescan && nmcli device wifi list"
          fi

          if command -v "curl" >/dev/null 2>&1; then
            alias derp="curl https://cht.sh/$1"
          fi

          if command -v "grep" >/dev/null 2>&1; then
            alias grep="grep --color=auto"
          fi

          if command -v "netstat" >/dev/null 2>&1; then
              alias ports="netstat -tulanp"
          fi

          if command -v "tree" >/dev/null 2>&1; then
            alias tree="tree -Cs"
          fi

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
                $EDITOR +"$linenumber" "$file"
              fi
            }
          fi

          # simple systemctl helpers using fzf
          if command -v "fzf" >/dev/null 2>&1; then
            _svc_select() {
              mode="$1"
              unit=$(systemctl $mode list-units --no-legend --all | awk '{print $1"\t"$2"\t"$3"\t"$4}' | \
                fzf --no-hscroll --preview "SYSTEMD_COLORS=1 systemctl $mode status {1}")
              printf "%s" "$unit" | awk '{print $1}'
            }

            sstart() { unit=$(_svc_select --system); [ -n "$unit" ] && sudo systemctl start "$unit"; }
            sstop()  { unit=$(_svc_select --system); [ -n "$unit" ] && sudo systemctl stop "$unit"; }
            srestart(){ unit=$(_svc_select --system); [ -n "$unit" ] && sudo systemctl restart "$unit"; }
            ustart() { unit=$(_svc_select --user); [ -n "$unit" ] && systemctl --user start "$unit"; }
            ustop()  { unit=$(_svc_select --user); [ -n "$unit" ] && systemctl --user stop "$unit"; }
            urestart(){ unit=$(_svc_select --user); [ -n "$unit" ] && systemctl --user restart "$unit"; }
          fi

          if [ -d "$HOME/.zshrc.d" ] ; then
            for script in $HOME/.zshrc.d/* ; do
                source $script
            done
          fi

          sir() {
               if [ -z "$1" ] || [ -z "$2" ] ; then echo "Search inside Replace: sir <find_string_named> <sring_replaced>" ; return 1 ; fi
               for file in $(rg -l "$1") ; do
                    sed -i "s|$1|$2|g" "$file"
               done
          }

          far() {
            if [ -z "$1" ] || [ -z "$2" ] ; then echo "Rename files: far <find_file_named> <file_renamed>" ; return 1 ; fi
            for file in $(find -name "$1") ; do
                 mv "$file" $(dirname "$file")/$2
            done
          }

          pkgrun () {
            if [ -n "$1" ] ; then
              pkg=$1
              if [ "$2" != "" ] ; then
                shift
                args="$@"
              else
                args=$pkg
              fi
              nix-shell -p $pkg.out --run "$args"
            fi
          }

          resetcow() {
            process_path() {
              path="$1"
              if [ -f "$path" ]; then
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

            target_name="$1"
            search_dir="$2"

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
        ohMyZsh = {
          enable = mkDefault true;
          plugins = [
            "alias-finder"
            "colored-man-pages"
            "colorize"
            "copyfile"
            "copypath"
            "direnv"
            "docker-compose"
            "docker"
            "extract"
            "git"
            "z"
          ];
        };
      };
    };
  };
}
