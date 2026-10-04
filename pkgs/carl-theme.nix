# The Carl suite, exposed as a SYSTEM-WIDE package.
#
# Why this exists at all: the greeter under Plasma Login Manager runs as its
# own user (`plasmalogin`), with its own HOME (/var/lib/plasmalogin). Everything
# modules/theming.nix installs lands in coru's home -- ~/.local/share/plasma/...,
# ~/.local/share/color-schemes/... and /etc/profiles/per-user/coru -- none of
# which the greeter can read. So to theme the login screen the same files have
# to exist in /run/current-system/sw as well.
#
# This only PLACES the files. Selecting them is a separate concern: Plasma Login
# Manager has no colour-scheme or theme setting (its KCM exposes only
# PreselectedSession and WallpaperPluginId), so the greeter picks these up as
# system-wide Plasma assets.
#
# The same vendored sources feed modules/theming.nix, so the greeter and the
# session cannot drift apart.
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

    # The vendored tree is read-only in the store; make the copies sane.
    chmod -R u+w $out

    runHook postInstall
  '';

  meta = {
    description = "Carl KDE theme suite (colour scheme, Look-and-Feel, desktop theme, Aurorae)";
    # Upstream is pling/KDE Store; see modules/theming.nix for why it is vendored.
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
