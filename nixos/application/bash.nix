{config, lib, pkgs, ...}:
let
  cfg = config.host.application.bash;
  shellAliases = {
    ".." = "cd .." ;
    "..." = "cd ..." ;
    home = "cd ~" ;
    fuck = "sudo $(history -p !!)" ;                                    # run last command as root
    mkdir = "mkdir -p" ;                                                # no error, create parents
    scstart = "systemctl start $@";                                     # systemd service start
    scstop = "systemctl stop $@";                                       # systemd service stop
    scenable = "systemctl disable $@";                                  # systemd service enable
    scdisable = "systemctl disable $@";                                 # systemd service disable
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
              ## Configure bash to append (rather than overwrite history)
              shopt -s histappend

              # Attempt to save all lines of a multiple-line command in the same entry
              shopt -s cmdhist

              ## After each command, append to the history file and reread it
              export PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND$"\n"}history -a; history -c; history -r"

              ## Print the timestamp of each command
              HISTTIMEFORMAT="%Y%m%d.%H%M%S%z "

              ## Set History File Size
              HISTFILESIZE=2000000

              ## Set History Size in memory
              HISTSIZE=3000

              ## Don't save ls,ps, history commands
              export HISTIGNORE="ls:ll:ls -alh:pwd:clear:history:ps"

              ## Do not store a duplicate of the last entered command and any commands prefixed with a space
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
  target_name="$1"
  search_dir="$2"

  if [ -z "$target_name" ]; then
    echo "Usage: resetcow <file_or_dir_name> [search_directory]"
    return 1
  fi

  if [ -z "$search_dir" ]; then
    path="$target_name"
    if [ -f "$path" ]; then
      perms=$(stat -c %a "$path")
      owner=$(stat -c %u "$path")
      group=$(stat -c %g "$path")
      touch "$path.nocow"
      chattr +c "$path.nocow"
      dd if="$path" of="$path.nocow" bs=1M
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
  else
    find "$search_dir" -name "$target_name" | while read path; do
      if [ -f "$path" ]; then
        perms=$(stat -c %a "$path")
        owner=$(stat -c %u "$path")
        group=$(stat -c %g "$path")
        touch "$path.nocow"
        chattr +c "$path.nocow"
        dd if="$path" of="$path.nocow" bs=1M
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
    done
  fi
}

        '';
      };
    };
  };
}
