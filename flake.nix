{
  description = "Behold, a garage door.";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/nixos/nixpkgs/0.1.tar.gz";
    fh.url = "github:DeterminateSystems/fh";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*";
  };

  outputs = { nixpkgs, ... } @ inputs: {
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

    nixosConfigurations.turner = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
        {
            environment.systemPackages = [ inputs.fh.packages.aarch64-linux.default ];
        }
      ];
    };
  };
}
