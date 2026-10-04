{ pkgs, ... }:

# Local LLM clients. cherry-studio is ours (pkgs/cherry-studio.nix), built from
# upstream's AppImage because nixpkgs lags. ~/.lmstudio lives in $HOME.
{
  home.packages = with pkgs; [
    lmstudio
    jan
    cherry-studio
  ];
}
