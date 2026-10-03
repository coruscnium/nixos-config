{ pkgs, ... }:

# Game launchers, mod clients, Proton/compat tooling, overlays.
#
# proton-cachyos comes from chaotic-nyx (the CachyOS-on-NixOS bridge) and is
# the equivalent of your proton-cachyos-native. On the NixOS side, register it
# with programs.steam.extraCompatPackages rather than installing it here alone.
#
# cheatengine-launcher (pkgs/default.nix) replaces cehelper.sh and the
# third-party Proton.SH script: protontricks-launch already resolves the right
# prefix from a Steam appid.
#
# mangohud / gamemode / steam themselves are NixOS modules (programs.*), not
# home packages.
{
  home.packages = with pkgs; [
    lutris
    heroic
    prismlauncher
    r2modman
    winboat
    vinegar

    protonup-qt
    protonplus
    proton-cachyos
    protontricks
    cheatengine-launcher
    reigntweak                    # Elden Ring: Nightreign ultrawide / 60fps

    # goverlay is DROPPED, not omitted by accident: it is a Lazarus/Free Pascal
    # app, so it pulls in lazarus-qt6, which fails to build on this nixpkgs
    # revision with
    #   #error --prefix NIX_LDFLAGS would introduce an empty PATH-like segment
    # That is a nixpkgs-side bug in the lazarus derivation (it dies in the final
    # check, after make install). Verified with:
    #   nix why-depends --derivation <nixos-vm.drv> <lazarus-qt6.drv>
    # mangojuice below covers MangoHud configuration, so nothing is lost.
    mangojuice                    # MangoHud config GUI
    vkbasalt
    lsfg-vk
    wineWow64Packages.stable

    pince                         # primary game-memory tool
  ];
}
