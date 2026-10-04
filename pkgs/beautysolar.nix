# BeautySolar — the solar-look sibling of BeautyLine.
#
# nixpkgs packages BeautyLine (beauty-line-icon-theme) but NOT BeautySolar.
# theming.nix used to ask for "BeautySolar" anyway, which is why the icon theme
# silently fell back: plasma-changeicons could not find it, the login script's
# `success` flag stayed 0, and the whole theme script re-ran every login.
#
# Upstream is a packaging mirror (musqz/beautysolar-icon-theme) rather than the
# original author's upload, kept deliberately: store.kde.org serves a bot
# challenge, so there is no stable fetchable URL from there. The mirror exists
# precisely so this is reproducible, and it is pinned by rev below.
#
# The mirror is a plain directory ("BeautySolar/") at the repo root, so this is
# a copy job -- no build system, no patching.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "beautysolar-icon-theme";
  version = "unstable-2026-07-17";

  src = fetchFromGitHub {
    owner = "musqz";
    repo = "beautysolar-icon-theme";
    rev = "d5d040d85ad234d520f7e25a46c872e066ea6df3";
    hash = "sha256-hYB14WttoLK4edAEagSj7DneBTIEAuHGXQuLi6fBQ+o=";
  };

  # The icon cache is built from the theme's own index; dropping it would make
  # icon lookups fall back to a slow directory scan.
  dontDropIconThemeCache = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons
    cp -r BeautySolar $out/share/icons/

    runHook postInstall
  '';

  meta = {
    description = "Solar-look icon theme based on BeautyLine";
    homepage = "https://github.com/musqz/beautysolar-icon-theme";
    # The mirror records GPL-3.0-only; BeautySolar/COPYING carries the text.
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
