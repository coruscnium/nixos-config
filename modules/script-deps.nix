{ pkgs, ... }:

# Runtime requirements of the ~/.local/bin scripts that are actually in use:
#   cover-extract.sh, embed_lyrics.sh, extract-here.sh, jan-clean,
#   toggle_pw_control_center.sh, mpv-single, streamcontroller-watchdog
#
# Listed explicitly so a script cannot silently break when something drops out
# of the closure. When those scripts become writeShellApplication derivations,
# these move into their runtimeInputs.
{
  home.packages = with pkgs; [
    kid3                           # embed_lyrics.sh -> kid3-cli
    socat                          # mpv-single -> IPC socket
    ffmpeg                         # cover-extract.sh
    p7zip                          # extract-here.sh -> 7z
    unrar                          # extract-here.sh -> unrar

    wireguard-tools                # replace Windscribe with native WireGuard
    streamcontroller               # custom units; see modules/services.nix
    lsyncd                         # lsyncd.service

    # NOT mcp-proxy: nixpkgs' mcp-proxy is a DIFFERENT tool (stdio <-> SSE).
    # Yours is the uv-installed PyPI package with --port /
    # --named-server-config, and uv keeps it self-contained under
    # ~/.local/share/uv, so it survives. services.nix points at it directly.
  ];
}
