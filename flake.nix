{
  description = "Behold, a garage door.";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/nixos/nixpkgs/0.1.tar.gz";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*";
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";

    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/0.1.1727.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane = {
      url = "https://flakehub.com/f/ipetkov/crane/0.16.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      version = "${builtins.substring 0 8 lastModifiedDate}-${self.shortRev or "dirty"}";

      pkgsFor = system: import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };

      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        inherit system;
        pkgs = pkgsFor system;
        lib = nixpkgs.lib;
      });
    in
    {

      schemas.nixosConfigurations = {
        version = 1;
        doc = ''
          The `nixosConfigurations` flake output defines [NixOS system configurations](https://nixos.org/manual/nixos/stable/#ch-configuration).
        '';
        inventory = output: inputs.flake-schemas.lib.mkChildren (builtins.mapAttrs
          (configName: machine:
            {
              what = "NixOS configuration";
              derivation = machine.config.system.build.toplevel;
              forSystems = [ machine.pkgs.system ];
            })
          output);
      };

      packages = forAllSystems ({ system, pkgs, ... }: {
        fenixToolchain = with inputs.fenix.packages.${system};
          combine ([
            stable.clippy
            stable.rustc
            stable.cargo
            stable.rustfmt
            stable.rust-src
          ]);


        server =
          let
            craneLib = (inputs.crane.mkLib pkgs).overrideToolchain self.packages.${system}.fenixToolchain;
          in
          craneLib.buildPackage {
            pname = "garage-door-opener-server";
            inherit version;
            src = ./garage-door-opener-server;

            doCheck = true;

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];
            buildInputs = with pkgs; [
              libiconv
            ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin
              (with pkgs.darwin.apple_sdk.frameworks; [ SystemConfiguration ]);
          };
      });

      devShells = forAllSystems ({ system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "dev";


            RUST_SRC_PATH = "${self.packages.${system}.fenixToolchain}/lib/rustlib/src/rust/library";

            nativeBuildInputs = with pkgs; [ pkg-config ];
            buildInputs = with pkgs; [
              self.packages.${system}.fenixToolchain
              rust-analyzer
              cargo-outdated
              cargo-limit
              cargo-watch
              nixpkgs-fmt
            ]
            ++ lib.optionals (pkgs.stdenv.isDarwin) (with pkgs; with darwin.apple_sdk.frameworks; [
              libiconv
              Security
              SystemConfiguration
            ]);
          };
        });


      nixosConfigurations.turner = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./configuration.nix
          inputs.nix.nixosModules.default
          {
            environment.systemPackages = [
                inputs.fh.packages.aarch64-linux.default
                nixpkgs.legacyPackages.aarch64-linux.raspberrypi-eeprom
            ];

            networking.firewall.allowedTCPPorts = [ 8080 ];

            systemd.services."garage-door-webserver" = {
                wantedBy = ["multi-user.target"];
                description = "Enable the garage door webserver.";
                path = [ pkgs.libgpiod ];
                script = ''${self.packages.aarch64-linux.server}/bin/garage-door-opener-server --ip 0.0.0.0 --port 8080'';
            };
          }
        ];
      };
    };
}
