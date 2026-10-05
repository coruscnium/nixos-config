{ pkgs, ... }:

# The local LLM client. cherry-studio is ours (pkgs/cherry-studio.nix), built
# from upstream's AppImage because nixpkgs lags.
{
  home.packages = with pkgs; [
    cherry-studio
  ];
}
