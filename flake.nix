{
  description = "Behold, a garage door.";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/nixos/nixpkgs/0.1.tar.gz";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.turner = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
      ];
    };
  };
}
