# AI desktop clients.
{ pkgs, ... }:
let
  # Cherry Studio has no current nixpkgs package: nixpkgs is stuck on 1.9.11
  # (the 2.x bump is an open PR) and pins an insecure Electron. So we wrap
  # upstream's AppImage instead. nvfetcher keeps version + hash fresh — see
  # nvfetcher.toml; run `nvfetcher` before rebuilding to pick up a release.
  sources = pkgs.callPackage ../../_sources/generated.nix { };
  harness = sources.cherry-studio;

  # Unpack once to reuse upstream's icon and metadata. Same inputs as the
  # extraction wrapType2 does internally, so Nix shares the one derivation.
  extracted = pkgs.appimageTools.extract { inherit (harness) pname version src; };

  # wrapType2 unpacks the AppImage at build time and wraps it in an FHS env,
  # so no FUSE or binfmt handler is needed to run it.
  cherry-studio = pkgs.appimageTools.wrapType2 {
    inherit (harness) pname version src;
  };
in
{
  home.packages = [ cherry-studio ];

  # wrapType2 yields the binary but no menu entry. Upstream's .desktop only
  # lives inside the AppImage, so restate it against the wrapped binary.
  xdg.desktopEntries.cherry-studio = {
    name = "Cherry Studio";
    comment = "A powerful AI assistant for producer.";
    exec = "cherry-studio %U";
    icon = "${extracted}/CherryStudio.png";
    categories = [ "Utility" "Network" ];
    mimeType = [ "x-scheme-handler/cherrystudio" ];
    settings.StartupWMClass = "CherryStudio";
  };
}
