{ pkgs, ... }:

# Game launchers, mod clients, Proton/compat tooling, overlays. steam / gamemode
# / mangohud are NixOS modules; proton-cachyos is registered with Steam there too
# (programs.steam.extraCompatPackages).
{
  home.packages = with pkgs; [
    heroic
    prismlauncher
    r2modman
    winboat
    vinegar

    protonup-qt
    protonplus
    proton-cachyos_x86_64_v3 # CachyOS Proton (SLR), x86-64-v3 for znver4
    protontricks
    reigntweak # Elden Ring: Nightreign ultrawide / 60fps

    # goverlay is dropped: it pulls in lazarus-qt6, which fails to build on this
    # nixpkgs revision. mangojuice covers MangoHud config.
    mangojuice
    vkbasalt
    lsfg-vk
    wineWow64Packages.stable

    pince # primary game-memory tool
  ];

  # User-facing mangohud + its config. Steam gets its own copy inside the sandbox
  # (nixos/gaming.nix); this covers a plain terminal.
  programs.mangohud.enable = true;
}
