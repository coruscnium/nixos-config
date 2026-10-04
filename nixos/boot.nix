{ config, lib, pkgs, ... }:

# Limine on the machine's 1 GiB ESP.
#
# This install no longer shares the ESP with a second OS, so the careful
# coexistence dance the old config needed is gone. What still matters: NixOS
# copies a kernel+initrd into /boot per generation, and maxGenerations caps how
# many are kept.
{
  # ---------------------------------------------------------------------------
  # LIMINE
  #
  #   NixOS binary  -> <esp>/efi/limine/BOOTX64.EFI   (non-removable install)
  #   NixOS config  -> <esp>/limine/limine.conf
  #
  # Limine searches, in order:
  #   <EFI app path>/limine.conf, /EFI/BOOT/limine.conf, /boot/limine/limine.conf,
  #   /boot/limine.conf, /limine/limine.conf, /limine.conf
  #
  # efiInstallAsRemovable stays FALSE, so NixOS's binary lives in \EFI\limine\
  # rather than claiming \EFI\BOOT\BOOTX64.EFI.
  #
  # MIGRATION NOTE: this machine boots via systemd-boot today -- that is what
  # the stock install used. Switching to Limine writes a new BOOTX64.EFI and
  # creates/updates an NVRAM entry. The previous systemd-boot entry remains in
  # the firmware boot menu, which is your way back if the new system will not
  # boot. For removing systemd-boot's leftovers afterwards, see MIGRATION.md.
  # ---------------------------------------------------------------------------
  boot.loader.limine = {
    enable = lib.mkDefault true;
    efiSupport = lib.mkDefault true;
    efiInstallAsRemovable = lib.mkDefault false;

    # Limine copies a kernel + initrd into /boot per generation. This ESP is
    # 1 GiB with ~980 MiB free, so 3 generations is comfortable. Raise it if you
    # want more rollback targets.
    maxGenerations = lib.mkDefault 3;
  };

  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = 5;

  # Boot menu wallpaper + a theme sampled from it. Limine only reads files from
  # the ESP, so NixOS copies this store path across and writes the entries into
  # limine.conf -- no additionalFiles needed.
  #
  # The image is pre-cropped to the ultrawide's 2.39:1 and re-encoded to JPEG at
  # exactly the interface mode, so Limine does a 1:1 blit and the loader stage
  # reads ~680 KiB instead of the original 11 MiB PNG. "stretched" fills the
  # screen with no distortion only if the interface matches that shape, hence
  # pinning interface.resolution to the panel's mode (Limine falls back to
  # another GOP mode if the firmware does not offer it).
  #
  # One display only: UEFI GOP is a single framebuffer, so Limine cannot crop
  # per-monitor. If the menu appears on a different screen, re-crop for that one.
  #
  # Colours come from the art -- a deep violet void (#110226) with a #693698
  # accent. Its text region sits at luma 9-21 (near black), so light text reads
  # cleanly with no solid panel behind it. Branding and help colours are certain;
  # the entry list is drawn through Limine's terminal palette, so foreground and
  # background theme it. The background keeps the wallpaper visible (the doc's
  # own 50%-transparent default) tinted toward the theme.
  boot.loader.limine.style = {
    wallpapers = [ ../boot/limine-wallpaper.jpg ];
    wallpaperStyle = "stretched";
    interface = {
      resolution = "3440x1440";
      branding = "CoruscOS";        # the OS name, provisional
      brandingColor = "B79BF0";     # title (Limine default is cyan #00AAAA)
      helpColor = "8E7BB8";         # keybind help (default green #00AA00)
      helpColorBright = "C9A9F5";   # boot-countdown digit
    };
    graphicalTerminal = {
      foreground = "D8CBEF";
      brightForeground = "EDE4FF";
      background = "800F0325";      # 50% transparent deep violet panel
      brightBackground = "532678";  # selected-entry bar, the image's accent
      palette = "0F0325;C05A7A;7FB58A;B08A5A;7A6FD0;B06FD0;6FB5C0;8E7BB8";
      brightPalette = "4A3A6B;E5809D;A6D4AE;E0C98A;9E93F0;D2A0F5;9AD4DE;EDE4FF";
    };
  };

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

  # Boot splash logo. The default bgrt theme runs the two-step plugin, which
  # draws the logo as a native-pixel watermark at bottom centre -- no scaling --
  # so the file must be pre-sized to what should appear on screen. NixOS ships
  # only a 48px default, which is near-invisible on a 3440px display. This is
  # Coru's art, downscaled from 1204px to 160px. Change 160 to resize it.
  #
  # (Aside: the same plugin draws the spinner at its native 32px, which is why
  # the splash reads as a blank grey screen -- there is nothing broken.)
  boot.plymouth.logo = ../boot/plymouth-logo.png;

  # rootflags MUST be on the kernel command line for a btrfs SUBVOLUME root:
  # the initrd has to find the subvolume before systemd remounts anything.
  #
  # It is DERIVED from fileSystems."/" rather than hardcoded, so the fstab entry
  # and the kernel command line can never disagree.
  #
  # Emit it ONLY when fileSystems."/" actually names a subvolume. Two cases
  # where it must be left off:
  #
  #   - a non-btrfs root. The VM variant uses plain ext4, and rootflags=subvol=
  #     to ext4 makes the kernel reject the mount.
  #
  #   - a root on the btrfs DEFAULT subvolume, which is what THIS machine has.
  #     There is no subvol= option to derive from, and the previous fallback of
  #     "subvol=@" was inherited from CachyOS -- it would have pointed the
  #     initrd at a subvolume that does not exist here, and the system would not
  #     have booted.
  #
  # "splash" is not listed here because boot.plymouth.enable already adds it
  # (it was appearing twice).
  boot.kernelParams = [
    "quiet"
    "nowatchdog"
  ] ++ (
    let
      rootSubvol = builtins.filter
        (o: lib.hasPrefix "subvol=" o)
        config.fileSystems."/".options;
    in
    lib.optionals
      (config.fileSystems."/".fsType == "btrfs" && rootSubvol != [ ])
      [ "rootflags=${builtins.head rootSubvol}" ]
  );

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
