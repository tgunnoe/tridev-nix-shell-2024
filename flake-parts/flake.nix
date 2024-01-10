{
  description = "TriDev with flake-parts & process-compose";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose.url = "github:Platonic-Systems/process-compose-flake";
    # For demo purposes
    chinookDb.url = "github:lerocha/chinook-database";
    chinookDb.flake = false;
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      imports = [ inputs.process-compose.flakeModule ];

      perSystem = { config, self', inputs', pkgs, lib, system, ... }: {

        devShells = {
          default = self'.devShells.tridev-shell;
          tridev-shell = pkgs.mkShell {
            name = "tridev-shell";
            buildInputs = with pkgs; [ git curl jq ];
            packages = with pkgs; [
              self'.packages.tridev-services
              pkgs.neovim
            ];
            shellHook = ''
              echo "Welcome to Tridev's official shell!";
            '';
          };
        };

        packages = {
          default = self'.packages.tridev-talk;
          tridev-talk = pkgs.writeShellApplication {
            name = "tridev-talk";
            runtimeInputs = [
              pkgs.ponysay
              pkgs.curl
              pkgs.w3m
            ];
            text = ''
            curl -s 'https://tricities.dev' | w3m -dump -T text/html
          '';
          };
        };

        # Process compose stuff

        process-compose."tridev-services" =
          let
            port = 8213;
            dataFile = "./.run/data.sqlite";
          in {
            port = 8081;
            settings = {
              environment = {
                SQLITE_WEB_PASSWORD = "demo";
              };

              processes = {
                # Print a pony every 2 seconds, because why not.
                ponysay.command = ''
                  while true; do
                    ${pkgs.ponysay}/bin/ponysay "Enjoy our sqlite-web demo!"
                    sleep 2
                  done
                '';

                # Create .sqlite database from chinook database.
                sqlite-init.command = ''
                  echo "$(date): Importing Chinook database (${dataFile}) ..."
                  ${lib.getExe pkgs.sqlite} "${dataFile}" < ${inputs.chinookDb}/ChinookDatabase/DataSources/Chinook_Sqlite.sql
                  echo "$(date): Done."
                '';

                # Run sqlite-web on the local chinook database.
                sqlite-web = {
                  command = ''
                    ${pkgs.sqlite-web}/bin/sqlite_web \
                      --password \
                      --port ${builtins.toString port} "${dataFile}"
                  '';
                  # The 'depends_on' will have this process wait until the above one is completed.
                  depends_on."sqlite-init".condition = "process_completed_successfully";
                  readiness_probe.http_get = {
                    host = "localhost";
                    inherit port;
                  };
                };

                test = {
                  command = pkgs.writeShellApplication {
                    name = "sqlite-web-test";
                    runtimeInputs = [ pkgs.curl ];
                    text = ''
                      curl -v http://localhost:${builtins.toString port}/
                    '';
                  };
                  depends_on."sqlite-web".condition = "process_healthy";
                };
              };
            };
          };

      }; # perSystem

      flake = {
        nixosConfigurations = {
          tridev-os = inputs.nixpkgs.lib.nixosSystem {
            modules = [
              { nixpkgs.hostPlatform = "x86_64-linux"; }
              ./system.nix
            ];
          };
        };
      };

    };
}
