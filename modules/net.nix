{ pkgs, ... }:

# Torrents, downloads, cloud storage and file sync.
#
# NUR does not merge into pkgs; its packages live under pkgs.nur.repos.
# forkprince.nuvio replaced the Nuvio AppImage in ~/.local/bin.
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
  ];
}
