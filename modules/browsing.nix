{ pkgs, ... }:

# Three browsers, each with a purpose: daily / secondary / anonymity.
# All are upstream-binary wrappers in nixpkgs, so they track releases closely.
# Do NOT add chromium + a Widevine override: it turns a cached binary into a
# multi-hour local source build.
{
  home.packages = with pkgs; [
    floorp-bin
    brave-origin
    tor-browser
  ];
}
