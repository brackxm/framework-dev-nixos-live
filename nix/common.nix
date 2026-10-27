{ lib, pkgs, ... }:
{
  # Shared settings for the live images and installed workstation.
  system.stateVersion = "26.05";
  networking.hostName = "dev";
  networking.networkmanager.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.zfs.forceImportRoot = false;

  # A public SSH key is safe to ship. Never put credentials in Nix expressions.
  users.users.nixos.openssh.authorizedKeys.keyFiles = [ ../ssh/authorized_keys ];
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git curl jq ripgrep procps iproute2 ethtool lsof
  ];
}
