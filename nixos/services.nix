{ config, lib, pkgs, ... }:

# System services. These are the things that CANNOT live in home-manager
# because they need root, a system daemon, or global state.
{
  networking.networkmanager.enable = true;

  # 1883 is the OctoEverywhere MQTT relay (nixos/octoeverywhere.nix publishes it
  # from the container). Docker writes its own iptables rules, so this entry is
  # belt-and-braces for LAN clients rather than strictly required.
  networking.firewall.allowedTCPPorts = [ 1883 ];

  # ---- Containers -----------------------------------------------------------
  # Docker is here rather than in octoeverywhere.nix so it exists even if you
  # drop that module. The oci-containers backend there depends on it.
  virtualisation.docker.enable = true;

  # ---- Storage --------------------------------------------------------------
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };
  services.fstrim.enable = true;          # discard=async is in fstab; this is belt-and-braces

  # ---- Sync / cloud ---------------------------------------------------------
  services.syncthing.enable = true;
  services.tailscale.enable = true;

  # ---- AI -------------------------------------------------------------------
  # Matches your local ollama. Models live under /var/lib/ollama, which is NOT
  # your CachyOS ~/.ollama -- re-pull them, or point OLLAMA_MODELS at the old
  # directory on /mnt/ssd2.
  services.ollama.enable = true;

  # ---- Performance ----------------------------------------------------------
  services.scx.enable = true;             # sched-ext; you had scx installed
  services.psd.enable = true;             # profile-sync-daemon (browser profiles)

  # ---- Flatpak --------------------------------------------------------------
  # nixpkgs' flatpak module has no app list, so nix-flatpak (imported in
  # flake.nix) adds services.flatpak.packages/remotes and installs/removes them
  # on activation. The flathub remote is added by default.
  #
  # Only the apps listed here are managed; flatpaks installed by hand are left
  # alone (uninstallUnmanaged is off). To make it prune them too, set
  # services.flatpak.uninstallUnmanaged = true.
  #
  # Two of your CachyOS flatpaks are EXCLUDED on purpose: com.hypixel.HytaleLauncher
  # and wtf.aubree.MacOBlox came from custom remotes (hytalelauncher-origin,
  # macoblox-origin) that do not exist here.
  #
  # Cherry Studio is NOT here -- it is packaged in-repo (pkgs/cherry-studio.nix,
  # built from the upstream AppImage). Sober is Flatpak-only (Roblox).
  services.flatpak = {
    enable = true;
    packages = [
      "org.vinegarhq.Sober"
      "app.fluxer.Fluxer"
      "com.stremio.Stremio"
      "com.unity.UnityHub"
      "com.usebottles.bottles"
      "io.github.loot.loot"
      "io.github.mhogomchungu.sirikali"
      "io.gitlab.adhami3310.Footage"
      "org.nickvision.tubeconverter"
      "org.onlyoffice.desktopeditors"
      "org.upscayl.Upscayl"
      "page.codeberg.libre_menu_editor.LibreMenuEditor"
    ];
  };

  # ---- Hardware hooks -------------------------------------------------------
  # Installs the udev rule shipped by the quadcast2s derivation, including its
  # SYSTEMD_USER_WANTS tag, which is what starts quadcast2s-hotplug. Without
  # this line the rule never reaches /etc/udev/rules.d.
  services.udev.packages = [ pkgs.quadcast2s ];

  # Secrets / keyring, as on CachyOS.
  services.gnome.gnome-keyring.enable = true;

  # Firmware updates.
  services.fwupd.enable = true;
}
