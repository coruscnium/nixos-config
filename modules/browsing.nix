{ pkgs, ... }:

# Daily / secondary / anonymity. Do NOT add chromium + a Widevine override -- it
# turns a cached binary into a multi-hour local source build.
{
  home.packages = with pkgs; [
    floorp-bin
    brave-origin
    tor-browser
  ];
}
