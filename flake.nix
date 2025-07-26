{
  description = "A collection of NixOS modules";
  inputs = {
  };
  outputs = { self, ... }@inputs:
    {
      nixosModules = import ./nixos;
    };
}
