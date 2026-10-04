# The Carl suite as a SYSTEM-WIDE package. The Plasma Login Manager greeter runs
# as its own user (plasmalogin) and cannot read coru's home, so the theme files
# have to exist in /run/current-system/sw. Feeds modules/theming.nix the same
# vendored sources, so the greeter and the session cannot drift apart.
{
  lib,
  stdenvNoCC,
  themesDir,
}:

stdenvNoCC.mkDerivation {
  pname = "carl-theme";
  version = "1.8";

  src = themesDir;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/color-schemes
    mkdir -p $out/share/plasma/look-and-feel
    mkdir -p $out/share/plasma/desktoptheme
    mkdir -p $out/share/aurorae/themes

    cp    Carl.colors        $out/share/color-schemes/Carl.colors
    cp -r look-and-feel-Carl $out/share/plasma/look-and-feel/Carl
    cp -r desktoptheme-Carl  $out/share/plasma/desktoptheme/Carl
    cp -r aurorae-Carl       $out/share/aurorae/themes/Carl

    chmod -R u+w $out

    runHook postInstall
  '';

  meta = {
    description = "Carl KDE theme suite (colour scheme, Look-and-Feel, desktop theme, Aurorae)";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
