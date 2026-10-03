{ config, lib, pkgs, ... }:

# Limine on the shared 2G ESP.
#
# IMPORTANT: the ESP has only ~482 MB free and CachyOS's own kernels are on it
# too. NixOS copies a kernel+initrd per generation into /boot, and the limine
# module's default maxGenerations is null (unlimited) -- which WILL fill it.
{
  # ---------------------------------------------------------------------------
  # LIMINE — the same bootloader CachyOS uses, and it coexists safely.
  #
  # Verified from nixpkgs' limine-install.py and Limine's own CONFIG.md:
  #
  #   NixOS binary  -> <esp>/efi/limine/BOOTX64.EFI   (non-removable install)
  #   NixOS config  -> <esp>/limine/limine.conf
  #   CachyOS keeps -> <esp>/limine.conf, \EFI\Limine\, \EFI\BOOT\BOOTX64.EFI
  #
  # Limine searches, in order:
  #   <EFI app path>/limine.conf, /EFI/BOOT/limine.conf, /boot/limine/limine.conf,
  #   /boot/limine.conf, /limine/limine.conf, /limine.conf
  # NixOS's config sits at position 5 and CachyOS's at position 6, so each
  # binary finds its own.
  #
  # efiInstallAsRemovable MUST stay FALSE. That is the single setting that keeps
  # NixOS's binary in \EFI\limine\ instead of writing \EFI\BOOT\BOOTX64.EFI --
  # which is exactly what CachyOS's Boot0000 entry points at. Set it true and
  # you overwrite the CachyOS boot entry.
  #
  # KNOWN INTERACTION: the installer searches for an existing NVRAM entry
  # labelled "Limine" and, if it finds one, deletes and recreates it pointing at
  # NixOS's binary. CachyOS's Boot0001 is labelled exactly "Limine", so that
  # entry WILL be repointed at NixOS. CachyOS stays bootable through its
  # "cachyos" entry (Boot0000). To avoid the reuse entirely, relabel it first:
  #     sudo efibootmgr -b 0001 -L CachyOS
  # ---------------------------------------------------------------------------
  boot.loader.limine = {
    enable = lib.mkDefault true;
    efiSupport = lib.mkDefault true;
    efiInstallAsRemovable = lib.mkDefault false;

    # The ESP is 2 GiB and SHARED with CachyOS's kernels, with only ~789 MiB
    # free. Limine copies a kernel + initrd into /boot per generation, so this
    # cap is what stops NixOS from filling the ESP. Lower it to 2 if it gets
    # tight.
    maxGenerations = lib.mkDefault 3;

    # TODO: add CachyOS here so the shared menu offers both systems. Fill in the
    # real filenames from `sudo ls -la /boot`, then uncomment:
    #
    # extraEntries = lib.mkDefault ''
    #
    #   /CachyOS
    #       protocol: linux
    #       kernel_path: boot():/vmlinuz-linux-cachyos
    #       module_path: boot():/initramfs-linux-cachyos.img
    #       cmdline: quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID=08a86259-d4d2-4bc9-b8c6-24da18aa2adb
    # '';
  };

  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = 5;

  # RDNA4 (RX 9070 XT) needs a recent kernel and mesa. chaotic-nyx's CachyOS
  # kernel provides exactly what you run today.
  #
  # This IS the latest: nyx's variants and their versions, verified --
  #   linuxPackages_cachyos              7.2.8   <-- default here, == your current
  #   linuxPackages_cachyos-lto-znver4   7.2.8   same version, GCC LTO + znver4
  #                                               tuning (the CachyOS "v4" build)
  #   linuxPackages_cachyos-lto          7.2.8
  #   linuxPackages_cachyos-bore/eevdf   7.2.8   scheduler variants
  #   linuxPackages_cachyos-rc           7.3-rc2 <-- the ONLY newer one
  #   linuxPackages_cachyos-lts          6.18.52
  #
  # The 7.3 release candidate is the only thing newer than what you have. It is
  # deliberately not the default: it is an RC, and if nyx has not built it into
  # their binary cache you would be compiling a kernel from source, which is
  # hours. Swap the line below if you want it anyway.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  boot.plymouth.enable = true;

  # rootflags MUST be on the kernel command line for a btrfs subvolume root: the
  # initrd has to find the subvolume before systemd remounts anything.
  #
  # It is DERIVED from fileSystems."/" rather than hardcoded, so the fstab entry
  # and the kernel command line can never disagree. Get this wrong and the
  # initrd mounts the wrong subvolume, or fails outright. Change the subvolume
  # in ONE place: the rootSubvol binding in hardware.nix.
  #
  # "splash" is not listed here because boot.plymouth.enable already adds it
  # (it was appearing twice).
  # Only emit rootflags when the root actually IS btrfs. The VM variant uses a
  # plain ext4 disk, and passing rootflags=subvol=@ to ext4 would make the kernel
  # reject the mount.
  boot.kernelParams = [
    "quiet"
    "nowatchdog"
  ] ++ lib.optionals (config.fileSystems."/".fsType == "btrfs") [
    "rootflags=${lib.findFirst (o: lib.hasPrefix "subvol=" o) "subvol=@" config.fileSystems."/".options}"
  ];

  boot.initrd.supportedFilesystems = [ "btrfs" ];
  boot.tmp.cleanOnBoot = true;

  # Clean up the store automatically. Without this, generations themselves
  # become the bloat you are trying to escape.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;
}
