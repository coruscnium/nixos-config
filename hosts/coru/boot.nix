{
  lib,
  pkgs,
  ...
}:

# Limine on the 1 GiB ESP. Keep everything on lib.mkDefault -- never mkForce.
{
  boot.loader.limine = {
    enable = lib.mkDefault true;
    efiSupport = lib.mkDefault true;
    efiInstallAsRemovable = lib.mkDefault false;
    maxGenerations = lib.mkDefault 3;
  };

  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = 5;

  # Boot menu wallpaper + a theme sampled from it. Re-encoded to JPEG at the
  # interface mode so Limine does a 1:1 blit. One display only (UEFI GOP is a
  # single framebuffer); "stretched" needs the shapes to match, hence the pinned
  # resolution.
  boot.loader.limine.style = {
    wallpapers = [ ../../boot/limine-wallpaper.jpg ];
    wallpaperStyle = "stretched";
    interface = {
      resolution = "3440x1440";
      branding = "CoruscOS";
      brandingColor = "B79BF0";
      helpColor = "8E7BB8";
      helpColorBright = "C9A9F5";
    };
    graphicalTerminal = {
      foreground = "D8CBEF";
      brightForeground = "EDE4FF";
      background = "800F0325";
      brightBackground = "532678";
      palette = "0F0325;C05A7A;7FB58A;B08A5A;7A6FD0;B06FD0;6FB5C0;8E7BB8";
      brightPalette = "4A3A6B;E5809D;A6D4AE;E0C98A;9E93F0;D2A0F5;9AD4DE;EDE4FF";
    };
  };

  # RDNA4 needs a recent kernel. linuxPackages_latest carries the same version
  # the CachyOS kernel shipped (7.2.9) without its patchset -- dropped back to
  # the stock kernel 2026-10-14, the patches had started causing bugs.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.plymouth.enable = true;

  # bgrt draws the logo as a native-pixel watermark, so the file size IS the
  # on-screen size (160px, down from 1204).
  boot.plymouth.logo = ../../boot/plymouth-logo.png;
}
