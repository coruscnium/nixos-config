# Category modules for coru's home-manager configuration.
# Imported by flake.nix as a single module; add new categories to this list.
{
  imports = [
    ./desktop.nix        # Plasma 6 apps, Qt theming, terminal
    ./browsing.nix
    ./messaging.nix
    ./media.nix          # video, capture, images
    ./audio.nix          # players, PipeWire tooling, EasyEffects stack
    ./graphics.nix       # 3D, CAD, 2D editors
    ./gaming.nix         # launchers, mod clients, Proton, overlays
    ./development.nix
    ./documents.nix
    ./net.nix            # torrents, downloads, cloud/sync
    ./files.nix          # file management, encryption, disks
    ./shell.nix          # zsh: prompt, completion, nix aliases
    ./shortcuts.nix      # global keyboard shortcuts (kglobalshortcutsrc)
    ./security.nix       # vaults, auth, privacy
    ./hardware.nix       # peripherals, monitoring, Wayland input
    ./ai.nix
    ./fonts.nix
    ./scripts.nix        # those scripts, as real packages
    ./services.nix       # custom systemd user units
    ./theming.nix        # Carl suite + the custom GTK port
  ];
}
