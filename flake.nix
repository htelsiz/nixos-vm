{
  description = "Universal NixOS VM configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
    let
      settings = import ./settings.nix;

      mkHost = { system, hostname, username }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; };
        modules = [
          disko.nixosModules.disko
          ./disko-config.nix
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${username} = import ./home.nix;
              extraSpecialArgs = { inherit username; };
            };
          }
        ];
      };
    in
    {
      nixosConfigurations.${settings.hostname} = mkHost {
        inherit (settings) system hostname username;
      };
    };
}
