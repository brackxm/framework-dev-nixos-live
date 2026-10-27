{ pkgs, ... }:
let
  toolchain = import ./toolchain.nix { inherit pkgs; };
in
{
  # Shared development toolchain. The live ISO includes ram-storage.nix separately.
  # Installed systems keep /workspace and /var/lib/docker on persistent disk.
  programs.nix-ld.enable = true;
  virtualisation.docker.enable = true;
  users.users.nixos.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    toolchain.node toolchain.pnpm
    python3 gcc gnumake postgresql_17
    git gh codex wrangler temporal-cli docker-compose elan zellij
    openssl wget unzip zip
    # The helper is embedded; proprietary executables are not.
    (writeShellScriptBin "install-runtime-tools"
      (builtins.readFile ../scripts/install-runtime-tools.sh))
  ];
}
