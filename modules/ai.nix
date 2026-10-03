{ pkgs, ... }:

# Local LLM clients. Both are AppImage wrappers in nixpkgs.
# ~/.lmstudio holds 8.1G of models and lives in $HOME, so it survives.
# ollama is a NixOS service (services.ollama.enable), not a home package.
# cherry-studio stays a Flatpak: nixpkgs is on 1.9.11 while you run 2.1.4.
{
  home.packages = with pkgs; [
    lmstudio
    jan
  ];
}
