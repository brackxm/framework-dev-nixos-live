{ pkgs, ... }:
let
  toolchain = import ./toolchain.nix { inherit pkgs; };
in
{
  imports = [ ./ram-storage.nix ];

  programs.nix-ld.enable = true;
  virtualisation.docker.enable = true;
  users.users.nixos.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    toolchain.node toolchain.pnpm
    python3 gcc gnumake postgresql_17
    git gh codex wrangler temporal-cli docker-compose elan
    openssl wget unzip zip
    # The helper is embedded; proprietary executables are not.
    (writeShellScriptBin "install-runtime-tools"
      (builtins.readFile ../scripts/install-runtime-tools.sh))
  ];
}
