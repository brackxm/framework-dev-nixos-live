{
  description = "Headless NixOS Live ISO for Framework Desktop dev workstation";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      mkIso = full: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./nix/base.nix ] ++ (if full then [ ./nix/dev.nix ] else [ ]);
      };
    in {
      nixosConfigurations.bootstrap = mkIso false;
      nixosConfigurations.dev = mkIso true;

      packages.${system}.bootstrapIso =
        (mkIso false).config.system.build.isoImage;
      packages.${system}.devIso =
        (mkIso true).config.system.build.isoImage;
    };
}
