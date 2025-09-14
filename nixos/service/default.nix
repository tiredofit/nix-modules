{lib, ...}:

with lib;
{
  imports = [
    ./coredns.nix
    ./eternal_terminal.nix
    ./fluent-bit.nix
    ./herald.nix
    ./iodine.nix
    ./logrotate.nix
    ./monit.nix
    ./ssh.nix
    ./syncthing.nix
    ./vscode_server.nix
    ./zabbix_agent.nix
    ./zeroplex.nix
  ];
}
