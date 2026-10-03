{ config, lib, pkgs, ... }:

# =============================================================================
# VM TEST VARIANT
#
# nixos-rebuild build-vm --flake .#coru   builds a QEMU script using
#   virtualisation.vmVariant  (nixpkgs: build-vm.nix)
# which re-evaluates this whole configuration with qemu-vm.nix added.
#
# Everything below ONLY affects that VM. The real system is untouched.
#
# WHAT THIS DEVIATES FROM THE REAL CONFIG, and therefore does NOT test:
#   * the btrfs subvolume root and the real disk UUIDs
#   * Limine / the shared ESP / the boot menu
#   * the GPU: no passthrough, so the desktop renders via virtio-gpu with
#     llvmpipe software rendering. Plasma will feel slow and GL apps will not work
#   * ROCm (dropped; pointless without a GPU, and several GB)
#   * Docker and the OctoEverywhere container (dropped; the VM cannot reach the
#     printer and the container would just churn)
#   * the Flatpak installs (needs Flathub over the network at activation)
#
# What it DOES test: that the system builds, boots, Plasma starts, plasma-manager
# applies the Carl theme, home-manager activates, and the user services behave.
# =============================================================================

{
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;                # you have 30G
      cores = 6;
      diskSize = 61440;                 # 60G virtual disk
      graphics = true;

      # Drop the container so the boot is not full of failed printer calls.
      docker.enable = lib.mkForce false;
      oci-containers.containers = lib.mkForce { };

      # A GPU-less VM cannot build/run these and they are large.
      # Uncomment to test the real GPU stack instead (needs passthrough).
      # (handled below via hardware.graphics)
    };

    # qemu-vm boots the kernel directly; there is no ESP and no Limine.
    boot.loader.limine.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
    boot.plymouth.enable = lib.mkForce false;

    # No ROCm/HIP: several GB, useless under virtio-gpu.
    hardware.graphics.extraPackages = lib.mkForce [ ];

    # ---- storage ----------------------------------------------------------
    # Verified behaviour: with this on, qemu-vm REPLACES the entire fileSystems
    # set with its own. The VM sees only:
    #   /  /nix/store  /nix/.ro-store  /nix/.rw-store  /tmp/shared  /tmp/xchg
    # i.e. none of the real UUID / btrfs-subvolume entries survive, and the root
    # is /dev/disk/by-label/nixos on ext4. That is why there is no per-mount
    # override list here -- there is nothing left to override.
    #
    # It is set EXPLICITLY rather than left to its default, so this behaviour is
    # pinned by this file and a future change of default cannot silently leave a
    # mount pointing at a disk the VM does not have (which drops it into
    # emergency mode).
    #
    # Consequence: the VM boots with a FRESH, EMPTY /home. That is exactly what
    # you want for a first test -- it validates home-manager from nothing,
    # without your real home directory interfering.
    virtualisation.useDefaultFilesystems = true;

    # ---- storage services that assume the real layout ---------------------
    # The VM has no btrfs filesystem at all, and the module asserts on that.
    services.btrfs.autoScrub.enable = lib.mkForce false;

    # ---- things that need the network at activation -----------------------
    networking.firewall.allowedTCPPorts = lib.mkForce [ ];

    # Clipboard / shutdown integration with the host.
    services.qemuGuest.enable = true;

    # Auto-login inside the VM, so a password problem cannot lock you out of the
    # test. (users.nix sets initialPassword = "changeme"; this makes it moot.)
    services.displayManager.autoLogin = {
      enable = true;
      user = "coru";
    };
  };
}
