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

  # NixOS registers our custom Proton with Steam via STEAM_EXTRA_COMPAT_TOOLS_PATHS,
  # but only inside Steam's own FHS profile. Tools run standalone (protontricks,
  # protonplus) never see that, so they cannot resolve the Steam-default Proton --
  # "Proton-CachyOS x86-64-v3" -- and bail with "Could not find configured Proton
  # installation!". Publish the same path to the whole session. It must be
  # environment.d, not home.sessionVariables: the latter only reaches login shells,
  # while the Protontricks GUI launches from Plasma. Steam re-assigns this var
  # identically in its own profile, so Steam itself is unaffected.
  xdg.configFile."environment.d/60-steam-compat-tools.conf".text = ''
    STEAM_EXTRA_COMPAT_TOOLS_PATHS=${pkgs.proton-cachyos_x86_64_v3}/
  '';

  # User-facing mangohud + its config. Steam gets its own copy inside the sandbox
  # (nixos/gaming.nix); this covers a plain terminal.
  programs.mangohud.enable = true;
}
