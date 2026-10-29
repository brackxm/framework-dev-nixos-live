{ pkgs, ... }:
{
  # Small, read-only diagnostics for the installed Framework Desktop.
  # CPU microcode, AMD P-state, GPU drivers, TRIM and framework-tool are
  # already provided by the pinned upstream nixos-hardware module.
  # No additional GPU memory, fan, firmware, or performance tuning is enabled.
  environment.systemPackages = with pkgs; [
    lm_sensors
    nvtopPackages.amd
    nvme-cli
    smartmontools
  ];
}
