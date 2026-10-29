{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ./common.nix
  ];

  # Live-only behavior. The installed OS does not use copytoram or tmpfs root.
  boot.kernelParams = [ "copytoram" ];
  boot.loader.timeout = lib.mkForce 2;

  # The installation image provides the nixos user; always start SSH.
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  security.sudo.wheelNeedsPassword = false;
}
