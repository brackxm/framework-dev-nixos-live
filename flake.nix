{
  description = "Headless NixOS live development environment";
  # Fixed 26.05 revision; commit a generated flake.lock after validation.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/1f607aa79b6356ed45d3cd3c8079c196e79efa2c";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      mkIso = full: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./nix/base.nix ] ++ (if full then [ ./nix/dev.nix ] else [ ]);
      };
      bootstrap = mkIso false;
      development = mkIso true;
    in {
      nixosConfigurations = {
        inherit bootstrap;
        dev = development;
      };
      packages.${system} = {
        bootstrapIso = bootstrap.config.system.build.isoImage;
        devIso = development.config.system.build.isoImage;
      };
      checks.${system} = {
        bootstrap = bootstrap.config.system.build.isoImage;
        dev = development.config.system.build.isoImage;
      };
    };
}
