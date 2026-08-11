{
  description = "Daniel's configuration flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    hyprland.url = "github:hyprwm/Hyprland";
    nix-colors.url = "github:misterio77/nix-colors";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    my_neovim = {
      url = "github:daniellaing/neovim";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    home-manager,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [inputs.devshell.flakeModule];
      systems = nixpkgs.lib.systems.flakeExposed;

      flake = {
        templates = import ./templates inputs;
        overlays = import ./overlays inputs;

        nixosConfigurations = let
          mkHost = {
            hostName,
            system,
          }:
            nixpkgs.lib.nixosSystem rec {
              inherit system;
              specialArgs = {inherit inputs;};

              modules = [
                {
                  networking = {inherit hostName;};
                  system = let
                    shortHash = self.shortRev or "dirty";
                  in {
                    configurationRevision = shortHash;
                    nixos.label = shortHash;
                  };
                  nixpkgs = {
                    overlays = [self.overlays.default inputs.nur.overlays.default];
                    config.allowUnfree = true;
                    hostPlatform = nixpkgs.lib.mkDefault system;
                  };
                }

                ./cooked

                ./hosts/${hostName}
                ./nixos/configuration.nix

                {
                  home-manager = {
                    useGlobalPkgs = true;
                    extraSpecialArgs = specialArgs;
                    users.daniel = import ./daniel;
                  };
                }

                home-manager.nixosModules.home-manager
              ];
            };
        in {
          dellG5 = mkHost {
            hostName = "dellG5";
            system = "x86_64-linux";
          };
          wsl = mkHost {
            hostName = "wsl";
            system = "x86_64-linux";
          };
        };
      };

      perSystem = {
        system,
        pkgs,
        ...
      }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };

        packages = import ./pkgs pkgs;
        formatter = pkgs.alejandra;
        devshells = import ./shell.nix {inherit pkgs;};
      };
    };
}
