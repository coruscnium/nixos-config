{
  config,
  lib,
  pkgs,
  ...
}:

# Boot policy every host shares: the loader choice, the kernel, the splash, and
# the derived kernel params. Anything that depends on the panel or the disk --
# the Limine wallpaper and interface resolution -- stays in hosts/<name>/boot.nix.
{
  # rootflags is DERIVED from fileSystems."/" and emitted only when it names a
  # subvolume. A root that is the btrfs DEFAULT subvolume (no subvol=) gets
  # nothing -- hardcoding subvol=@ would point the initrd at a subvolume that
  # does not exist and the system would not boot.
  boot.kernelParams = [
    "quiet"
    "nowatchdog"
  ]
  ++ (
    let
      rootSubvol = builtins.filter (o: lib.hasPrefix "subvol=" o) config.fileSystems."/".options;
    in
    lib.optionals (config.fileSystems."/".fsType == "btrfs" && rootSubvol != [ ]) [
      "rootflags=${builtins.head rootSubvol}"
    ]
  );

  boot.initrd.supportedFilesystems = [ "btrfs" ];
  boot.tmp.cleanOnBoot = true;

  # ntsync is Wine's in-kernel replacement for fsync/esync. Proton switches to it
  # automatically the moment /dev/ntsync exists (opt-out is PROTON_NO_NTSYNC), and
  # it is what stops VRChat dying with Mono's "SuspendThread loop failed" -- the
  # fsync path loses thread suspensions the GC is waiting on. CONFIG_NTSYNC is =m
  # in linuxPackages_latest, so the module has to be asked for explicitly.
  boot.kernelModules = [ "ntsync" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # --- loader ---------------------------------------------------------------
  # Limine owns both ESPs. Keep every switchable setting on lib.mkDefault --
  # never mkForce; a host that needs a different value (or the installer's own
  # defaults) must be able to override without fighting this file.
  boot.loader.limine = {
    enable = lib.mkDefault true;
    efiSupport = lib.mkDefault true;
    efiInstallAsRemovable = lib.mkDefault false;
    maxGenerations = lib.mkDefault 3;
  };

  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = 5;

  # CoruscOS branding and palette, identical on both panels. The wallpaper and
  # the interface resolution are per-host: the desktop pins an ultrawide mode so
  # its JPEG is a 1:1 blit, the laptop lets the firmware pick the mode.
  boot.loader.limine.style = {
    interface = {
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

  # Stock kernel, not the CachyOS patchset: linuxPackages_latest carries the
  # same version (7.2.9) without the patches that started misbehaving
  # 2026-10-14. mkDefault so a host can pin something else.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  boot.plymouth.enable = true;
  # bgrt draws the logo as a native-pixel watermark, so the file size IS the
  # on-screen size (160px, down from 1204).
  boot.plymouth.logo = ../boot/plymouth-logo.png;
}
