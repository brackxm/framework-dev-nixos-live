{ lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  system.stateVersion = "26.05";
  networking.hostName = "dev";
  networking.networkmanager.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # The upstream installer profile includes ZFS, which is incompatible with
  # the latest kernel at this pinned revision. This live image uses ext4.
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.zfs.forceImportRoot = false;
  boot.kernelParams = [ "copytoram" ];
  boot.loader.timeout = lib.mkForce 2;

  # Only an SSH PUBLIC key. No tokens or private keys belong in the ISO.
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

  # The live installer module can override sshd activation.
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  security.sudo.wheelNeedsPassword = false;

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
