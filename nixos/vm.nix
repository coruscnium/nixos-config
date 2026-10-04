{ config, lib, pkgs, ... }:

# VM TEST VARIANT -- `nixos-rebuild build-vm --flake .#coru`. Only affects the VM.
#
# Does NOT test: the btrfs/UUID layout, Limine, the GPU (virtio-gpu only), ROCm,
# Docker/OctoEverywhere, or the Flatpak installs. Tests that the system builds,
# boots, Plasma starts, plasma-manager applies the theme and home-manager
# activates -- on a fresh, empty /home.
{
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 6;
      diskSize = 61440;
      graphics = true;

      docker.enable = lib.mkForce false;
      oci-containers.containers = lib.mkForce { };
    };

    boot.loader.limine.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
    boot.plymouth.enable = lib.mkForce false;

    hardware.graphics.extraPackages = lib.mkForce [ ];

    # Set explicitly: with this on, qemu-vm REPLACES the whole fileSystems set with
    # its own, so no real UUID survives and / is ext4. Pinned so a future change of
    # default cannot leave a mount pointing at a disk the VM lacks.
    virtualisation.useDefaultFilesystems = true;

    services.btrfs.autoScrub.enable = lib.mkForce false;

    networking.firewall.allowedTCPPorts = lib.mkForce [ ];

    services.qemuGuest.enable = true;

    services.displayManager.autoLogin = {
      enable = true;
      user = "coru";
    };
  };
}
