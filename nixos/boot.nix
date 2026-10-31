{
  config,
  lib,
  ...
}:

# Boot policy every host shares. The loader itself, the kernel, and any splash
# assets are per-host -- see hosts/<name>/boot.nix.
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

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;
}
