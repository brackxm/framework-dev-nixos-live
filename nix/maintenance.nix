{ ... }:
{
  # Persistent installations only. The live ISO stays disposable, and neither
  # schedule deletes project files or Docker volumes.
  nix.gc = {
    automatic = true;
    dates = "Sun 03:00";
    # Keep recent NixOS generations available for rollback.
    options = "--delete-older-than 30d";
  };

  # Deduplicate identical Nix store files after garbage collection.
  nix.optimise = {
    automatic = true;
    dates = "Sun 05:00";
  };
}
