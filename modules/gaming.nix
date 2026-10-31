{ pkgs, ... }:

# The basic gaming userland every host gets: launchers, mod clients, and the
# Proton/compat tooling that has to resolve the same Proton Steam does. Desk-only
# pieces -- VR, the Roblox routes, the ultrawide fix -- live in hosts/coru/hm.nix.
{
  home.packages = with pkgs; [
    heroic
    prismlauncher
    r2modman

    protonup-qt
    protonplus
    proton-cachyos_x86_64_v3 # CachyOS Proton (SLR), x86-64-v3
    protontricks

    # goverlay is dropped: it pulls in lazarus-qt6, which fails to build on this
    # nixpkgs revision. mangojuice covers MangoHud config.
    mangojuice
    vkbasalt
    lsfg-vk
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

  # CoruFrame -- Coru's Warframe companion (relic reward HUD, inventory ledger,
  # market tools). Upstream flake's home-manager module; the one package carries
  # both `coruframe-app` and the `coruframe` CLI, with Tesseract on their PATH.
  # The HUD needs KWin's wlr-layer-shell plus a one-time portal screencast grant.
  # Both hosts run Plasma 6, so it is shared.
  programs.coruframe.enable = true;
}
