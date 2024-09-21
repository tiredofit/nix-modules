{lib, ...}:

with lib;
{
  imports = [
    ./application/default.nix
    ./container/default.nix
    ./feature/default.nix
    ./filesystem/default.nix
    ./hardware/default.nix
    ./network/default.nix
    ./roles/default.nix
    ./service/default.nix
  ];
}
