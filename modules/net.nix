{ pkgs, ... }:

# Torrents, downloads, cloud storage and file sync. lsyncd and wireguard-tools
# are backed by the systemd user units in modules/services.nix.
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

    lsyncd
    wireguard-tools
  ];
}
