{ pkgs, ... }:
{
  # RAM-backed tmpfs holds a sparse ext4 disk image for Docker overlay2.
  # The maximum sizes below are limits, not reservations of physical RAM.
  fileSystems."/var/lib/dev-ram" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=20G" "mode=0700" "nosuid" "nodev" ];
  };
  fileSystems."/workspace" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=12G" "mode=1777" "nosuid" "nodev" ];
  };

  systemd.services.docker-ramdisk = {
    description = "Mount volatile ext4-backed Docker data";
    before = [ "docker.service" ];
    requiredBy = [ "docker.service" ];
    unitConfig.RequiresMountsFor = "/var/lib/dev-ram";
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    script = ''
      set -eu
      image=/var/lib/dev-ram/docker.ext4
      ${pkgs.coreutils}/bin/install -d -m 0700 /var/lib/docker
      if ! ${pkgs.util-linux}/bin/mountpoint -q /var/lib/docker; then
        if test ! -f "$image"; then
          ${pkgs.coreutils}/bin/truncate -s 16G "$image"
          ${pkgs.e2fsprogs}/bin/mkfs.ext4 -F -q "$image"
        fi
        ${pkgs.util-linux}/bin/mount -t ext4 -o loop,noatime "$image" /var/lib/docker
      fi
    '';
  };
  systemd.services.docker.requires = [ "docker-ramdisk.service" ];
  systemd.services.docker.after = [ "docker-ramdisk.service" ];
}
