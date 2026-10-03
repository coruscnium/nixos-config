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
  # The NixOS flatpak module has NO declarative app list (its options are just
  # enable / package / extraPortals), so the apps cannot be declared here. This
  # enables the plumbing; install the apps once after first boot with the
  # command below.
  #
  # Two of your CachyOS flatpaks are EXCLUDED on purpose: com.hypixel.HytaleLauncher
  # and wtf.aubree.MacOBlox came from custom remotes (hytalelauncher-origin,
  # macoblox-origin) that do not exist here.
  #
  #   flatpak install -y flathub \
  #     com.cherry_ai.CherryStudio org.vinegarhq.Sober app.fluxer.Fluxer \
  #     com.stremio.Stremio com.unity.UnityHub com.usebottles.bottles \
  #     io.github.loot.loot io.github.mhogomchungu.sirikali \
  #     io.gitlab.adhami3310.Footage net.blockbench.Blockbench \
  #     org.nickvision.tubeconverter org.onlyoffice.desktopeditors \
  #     org.upscayl.Upscayl page.codeberg.libre_menu_editor.LibreMenuEditor
  #
  # CherryStudio is the one that matters: nixpkgs is a full major version behind
  # (1.9.11 vs your 2.1.4). Sober is Flatpak-only (Roblox).
  services.flatpak.enable = true;

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
