{ pkgs, config, ... }:

# The desktop's own home config -- everything that is bound to this desk: the
# peripherals, the 3D-printing tools, the desk's user units, and the gaming
# userland that needs this hardware (the VR runtime pair, the Roblox routes, the
# ultrawide fix, the mod managers for the games installed here). The shared set
# is ../../modules, which the laptop imports wholesale.
{
  imports = [
    ../../modules/hardware.nix
    ../../modules/maker.nix
    ../../modules/services-desktop.nix
  ];

  home.packages = with pkgs; [
    # Beat Saber. BSManager is BSMG's recommended mod installer and downgrader,
    # so a game update cannot break mods out from under it. In nixpkgs, so it is
    # a home package -- unlike Amethyst (services.flatpak), whose AppImage has
    # stripped section headers and cannot be wrapped.
    bs-manager
    ddmm # Helldivers 2 mod manager, Tauri binary (pkgs/ddmm.nix)
    winboat
    vinegar

    # Roblox, the other way round: nutmeg runs the *macOS* client through
    # rosemary (pkgs/nutmeg.nix), where vinegar/Sober run the Android one. Two
    # independent clients -- installing nutmeg does not disturb Sober. Its
    # roblox: URL handlers are registered per-user by `nutmeg install-desktop`,
    # not declaratively.
    nutmeg

    reigntweak # Elden Ring: Nightreign ultrawide / 60fps
    wineWow64Packages.stable
    pince # primary game-memory tool

    # The Stream Deck's watchdog, next to the unit that runs it
    # (modules/services-desktop.nix). Desk-only, so not in modules/scripts.nix.
    script-streamcontroller-watchdog

    # VR. The WiVRn server, its Monado runtime, and -- via
    # config.json.application -- the wayvr overlay all come from services.wivrn
    # (hosts/coru/vr.nix), so they are NOT listed here (nothing installed twice).
    # olsvr is not here either: its user unit is shared policy, so the package
    # sits with it in modules/services.nix.
    xrizer # OpenVR -> OpenXR, so SteamVR titles (VRChat) run under WiVRn
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
