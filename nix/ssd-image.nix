{ ... }:
{
  # Overrides for the flashable raw-efi image only. The regular installed
  # configuration remains usable with nixos-install on an SSD.
  image.modules.raw-efi = {
    config, lib, pkgs, modulesPath, ...
  }: {
    image.baseName = "framework-dev-ssd";

    # The image builder runs without host EFI variables. systemd-boot also
    # installs the removable-media fallback EFI binary for first boot.
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # The upstream raw-efi image module provides GPT, an ESP labelled ESP,
    # an ext4 root labelled nixos, and boot.growPartition/autoResize.
    # Increase its stock 256 MiB ESP to 1 GiB for future NixOS generations.
    # Avoid copying a Nixpkgs channel: updates use the pinned GitHub flake.
    system.build.image = lib.mkForce (import (modulesPath + "/../lib/make-disk-image.nix") {
      inherit lib config pkgs;
      inherit (config.virtualisation) diskSize;
      inherit (config.image) baseName format;
      partitionTableType = "efi";
      bootSize = "1024M";
      copyChannel = false;
    });
  };
}
