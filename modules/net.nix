{ pkgs, ... }:

# Torrents, downloads, cloud storage and file sync.
#
# NUR does not merge into pkgs; its packages live under pkgs.nur.repos.
# forkprince.nuvio replaced the Nuvio AppImage in ~/.local/bin.
#
# lsyncd and wireguard-tools are tools rather than apps, but they belong here:
# both are backed by custom systemd user units (see modules/services.nix), so
# the packages only need to exist, not be launched by hand.
{
  home.packages = with pkgs; [
    qbittorrent
    nicotine-plus
    newsflash
    yt-dlp
    localsend
    syncthingtray
    megacmd
    megasync
    nur.repos.forkprince.nuvio

    lsyncd                         # lsyncd.service (file sync mirror)
    wireguard-tools                # replaces Windscribe with native WireGuard
  ];
}
