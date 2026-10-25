{ pkgs, ... }:
{
  # Helps upstream Node packages that download precompiled Linux binaries.
  programs.nix-ld.enable = true;

  virtualisation.docker.enable = true;
  users.users.nixos.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    # Exact Node 24.22.1 / pnpm 11.25.0 pins still require verification.
    nodejs_24 pnpm python3 gcc gnumake
    postgresql_17

    # Open-source tools are included in the live image.
    gh codex wrangler
    temporal-cli docker-compose
    openssl wget unzip zip

    # Explicit on-demand installer, without proprietary binaries in the ISO.
    (writeShellScriptBin "install-runtime-tools"
      (builtins.readFile ../scripts/install-runtime-tools.sh))
  ];
}
