{ pkgs, ... }:
{
  # Persistent headless NixOS installation, not an ISO profile.
  imports = [
    ./common.nix
    ./dev.nix
    ./ssd-image.nix
    ./maintenance.nix
    ./hardware/framework-desktop.nix
  ];

  # UEFI boot. Disk formatting is NEVER performed by evaluating this module.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  # Generic initrd support for internal NVMe and common recovery devices.
  # Revisit after nixos-generate-config if additional hardware modules are needed.
  boot.initrd.availableKernelModules = [
    "nvme" "ahci" "xhci_pci" "usb_storage" "sd_mod"
  ];

  # Stable labels avoid hardcoding a device model, serial number or /dev/nvmeXnY.
  # See docs/install-to-ssd.md before creating/formatting any partition.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  hardware.enableRedistributableFirmware = true;

  # Enable LVFS firmware discovery and manual updates via fwupdmgr.
  # Firmware is not flashed automatically during NixOS installation.
  services.fwupd.enable = true;

  # The live ISO creates its own nixos account. Define the account explicitly
  # on an installed system; SSH access comes from ./common.nix.
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
  security.sudo.wheelNeedsPassword = false;

  # This directory and all development state survive reboots.
  # /var/lib/docker uses the regular persistent root filesystem (ext4).
  systemd.tmpfiles.rules = [
    "d /workspace 0775 nixos users -"
  ];
}
