# Cherry Studio — built from upstream's AppImage.
#
# nixpkgs does package it, but at 1.9.11: a full major version behind the 2.1.4
# we actually run, and the 2.x bump there pins an insecure Electron. So we wrap
# upstream's AppImage instead.
#
# The version and hash live in ../_sources/generated.nix, which nvfetcher
# rewrites. Bumping is therefore a command, not a hand-edited SHA:
#
#   nix run nixpkgs#nvfetcher && nixos-rebuild switch --flake .#coru
#
# This is the harness this whole configuration is developed in, so it is worth
# having reproducibly installed rather than copied around by hand.
{ lib, appimageTools, callPackage }:

let
  sources = callPackage ../_sources/generated.nix { };
  inherit (sources.cherry-studio) pname version src;
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Electron apps need a few things the default AppImage wrapper does not pull
  # in. If Cherry Studio fails to start with a "cannot open shared object"
  # error, add the named library here.
  extraPkgs = pkgs: with pkgs; [
    libsecret
    libuuid
    libGL
    icu
    nss
  ];

  meta = {
    description = "Desktop AI assistant / LLM client (upstream AppImage)";
    homepage = "https://github.com/CherryHQ/cherry-studio";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cherry-studio";
  };
}
