{
  description = "Behold, a garage door.";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/nixos/nixpkgs/0.1.tar.gz";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*";
  };

  outputs = { nixpkgs, ... }: {
    schemas = inputs.flake-schemas.schemas;

    nixosConfigurations.turner = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
      ];
    };
  };
}
