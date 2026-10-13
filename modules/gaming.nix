{ pkgs, config, ... }:

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

    # VR. The WiVRn server, its Monado runtime, and -- via
    # config.json.application -- the wayvr overlay all come from services.wivrn
    # (nixos/gaming.nix), so they are NOT listed here (nothing installed twice).
    xrizer # OpenVR -> OpenXR, so SteamVR titles (VRChat) run under WiVRn
    olsvr # Wayland OLED burn-in screensaver (pkgs/olsvr.nix)
  ];

  # Point the OpenVR runtime at xrizer, which translates OpenVR -> OpenXR and
  # hands the game to WiVRn. Without this SteamVR stays the OpenVR runtime and
  # every OpenVR title (VRChat) launches the broken SteamVR instead. SteamVR
  # writes this file itself, so it is a store symlink -- read-only, SteamVR
  # cannot put itself back. SteamVR's config/log dirs are preserved for if it
  # is ever used directly.
  xdg.configFile."openvr/openvrpaths.vrpath".text = builtins.toJSON {
    version = 1;
    jsonid = "vrpathreg";
    external_drivers = null;
    runtime = [ "${pkgs.xrizer}/lib/xrizer" ];
    config = [ "${config.xdg.dataHome}/Steam/config" ];
    log = [ "${config.xdg.dataHome}/Steam/logs" ];
  };

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

  # Rosemary as a Steam compatibility tool -- drops it into
  # compatibilitytools.d so a macOS app runs under Steam's "Rosemary" entry.
  # Rosemary itself is a system runtime (nixos/system.nix, pkgs.rosemary);
  # pin `package` to that build so the tool reuses it instead of the flake's
  # own default derivation. Upstream module: rosemary.homeManagerModules.default.
  programs.rosemary = {
    steam.enable = true;
    package = pkgs.rosemary;
  };
}
