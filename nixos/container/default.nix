{lib, ...}:

with lib;
{
  imports = [
    ./coredns.nix
    ./clamav.nix
    ./fluentbit.nix
    ./llng-handler.nix
    ./openldap.nix
    ./postfix-relay.nix
    ./restic.nix
    ./s3ql.nix
    ./socket-proxy.nix
    ./tcc.nix
    ./tinc.nix
    ./traefik.nix
    ./traefik-internal.nix
    ./unbound.nix
    ./zabbix-proxy.nix
  ];
}