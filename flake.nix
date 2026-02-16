{
  description = "Universal NixOS VM configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    claude-desktop-linux = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      disko,
      home-manager,
      fenix,
      llm-agents,
      stylix,
      plasma-manager,
      claude-desktop-linux,
      ...
    }@inputs:
    let
      settings = import ./settings.nix;

      mkHost = { system, hostname, username }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; };
        modules = [
          # Overlays: unstable packages, AI tools, Rust toolchains
          (_: {
            nixpkgs.overlays = [
              (_final: _prev: {
                unstable = import nixpkgs-unstable {
                  inherit system;
                  config.allowUnfree = true;
                };
              })
              (_final: _prev: {
                llm-agents = llm-agents.packages.${system};
              })
              fenix.overlays.default
            ];
          })

          # Stylix system-wide theming
          stylix.nixosModules.stylix

          disko.nixosModules.disko
          ./disko-config.nix
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              sharedModules = [ plasma-manager.homeModules.plasma-manager ];
              users.${username} = import ./home.nix;
              extraSpecialArgs = { inherit username inputs; };
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
