{ pkgs, ... }:

# Local LLM clients. All are AppImage wrappers.
# ~/.lmstudio holds 8.1G of models and lives in $HOME, so it survives.
# ollama is a NixOS service (services.ollama.enable), not a home package.
#
# cherry-studio is OURS (pkgs/cherry-studio.nix), not nixpkgs': nixpkgs is on
# 1.9.11 while we run 2.1.4, so it wraps upstream's AppImage with a version
# pinned by nvfetcher. This is also the harness this config is built in.
{
  home.packages = with pkgs; [
    lmstudio
    jan
    cherry-studio
  ];
}
