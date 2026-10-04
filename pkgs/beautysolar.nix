# BeautySolar -- the solar-look sibling of BeautyLine. nixpkgs carries BeautyLine
# but not this one, which is why the old iconTheme name silently fell back.
# Pinned to a packaging mirror (store.kde.org serves a bot challenge).
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

  # The icon cache is built from the theme's own index; dropping it would fall
  # back to a slow directory scan.
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
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
