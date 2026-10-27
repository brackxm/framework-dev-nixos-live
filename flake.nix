{
  description = "Headless NixOS development environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/1f607aa79b6356ed45d3cd3c8079c196e79efa2c";
  # Pin Framework Desktop hardware support to a reviewed upstream revision.
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/1b418b8f203e49a92f250f8babdd19af1b6f7a7f";
  inputs.nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, nixos-hardware, ... }:
    let
      system = "x86_64-linux";
      mkIso = full: nixpkgs.lib.nixosSystem {
        inherit system;
        modules =
          [ ./nix/base.nix ]
          ++ (if full then [ ./nix/dev.nix ./nix/ram-storage.nix ] else [ ]);
      };
      bootstrap = mkIso false;
      development = mkIso true;
      installed = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./nix/installed.nix
          nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
        ];
      };
    in {
      nixosConfigurations = {
        inherit bootstrap installed;
        devLive = development;
      };

      packages.${system} = {
        bootstrapIso = bootstrap.config.system.build.isoImage;
        devIso = development.config.system.build.isoImage;
        installedSystem = installed.config.system.build.toplevel;
        ssdImage = installed.config.system.build.images.raw-efi;
      };

      checks.${system} = {
        bootstrap = bootstrap.config.system.build.isoImage;
        devLive = development.config.system.build.isoImage;
        installed = installed.config.system.build.toplevel;
        ssdImage = installed.config.system.build.images.raw-efi;
      };
    };
}
