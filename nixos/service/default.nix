{lib, ...}:

with lib;
{
  imports = [
    ./dns-companion.nix
    ./docker_container_manager.nix
    ./coredns.nix
    ./eternal_terminal.nix
    ./fluent-bit.nix
    ./iodine.nix
    ./logrotate.nix
    ./monit.nix
    ./ssh.nix
    ./syncthing.nix
    ./vscode_server.nix
    ./zabbix_agent.nix
    ./zt-dns-manager.nix
  ];
}
