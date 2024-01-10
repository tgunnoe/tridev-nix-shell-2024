{
  description = "Tridev flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:nixos/nixpkgs/46ae0210ce163b3cba6c7da08840c1d63de9c701";
    #nixpkgs.url = "path:/home/tgunnoe/src/nixpkgs";
  };
  outputs = inputs @ { self, nixpkgs, nixpkgs-old, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgsOld = inputs.nixpkgs-old.legacyPackages.${system};
    in {

      packages = {
        x86_64-linux = {
          # writeShellApplication is part of nixpkgs
          tridev-talk = pkgs.writeShellApplication {
            name = "tridev-talk";
            runtimeInputs = [
              pkgs.ponysay
              pkgs.curl
              pkgs.w3m
              #pkgsOld.nodejs_16
            ];
            text = ''
            curl -s 'https://tricities.dev' | w3m -dump -T text/html
          '';
          };
        };
      };
      checks.${system} = {

      };
      devShells.${system} = {
        tridev-shell =  pkgs.mkShell {
          name = "tridev-shell";
          buildInputs = with pkgs; [
            git
            curl
            jq
            neovim
            maven

            # ...
          ];
          shellHook = ''
            echo "Welcome to Tridev's official shell!";
          '';
        };
      };

      nixosConfigurations = {
        tridev-os = inputs.nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.hostPlatform = "${system}"; }
            ./system.nix
          ];
        };
      };

    };
}
