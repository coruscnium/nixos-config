{ lib, pkgs, ... }:

# Zsh: the interactive shell coru lives in.
#
# The login shell itself is set elsewhere -- nixos/users.nix picks pkgs.zsh and
# turns on programs.zsh system-wide. This module owns the *user* side: prompt,
# autosuggestions, completion and the nix aliases. ~/.zshrc is generated from
# here, so the hand-written one is replaced; home-manager backs it up to
# ~/.zshrc.hm-backup rather than clobbering it (backupFileExtension is set in
# flake.nix).
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;          # fish-style inline suggestions
    syntaxHighlighting.enable = true;      # command validity as you type
    historySubstringSearch.enable = true;  # up/down through matching history

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;                  # a leading space keeps a command out
      share = true;                        # history shared across sessions
    };

    # fzf-tab replaces zsh's completion menu with an fzf picker. It must load
    # AFTER compinit -- home-manager runs compinit at order 570 but sources
    # plugins at 900, which is why this works without manual ordering.
    plugins = [
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      }
    ];

    # p10k is sourced last (order 1300, after syntax-highlighting at 1200), as
    # upstream expects. BOTH lines are required: the theme only *defines* the
    # prompt, and it refuses to trust a config it did not see sourced -- if no
    # POWERLEVEL9K_* variable is set, p10k assumes it is unconfigured and launches
    # its wizard on the first prompt. Sourcing ~/.p10k.zsh is what stops that.
    #
    # The prompt config is vendored at zsh/p10k.zsh and placed as ~/.p10k.zsh
    # below, so it is reproducible instead of a loose file in $HOME. To change it:
    # run `p10k configure`, copy the result back over zsh/p10k.zsh, rebuild (the
    # managed ~/.p10k.zsh is a read-only store symlink).
    initContent = lib.mkMerge [
      (lib.mkOrder 1300 ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      '')
    ];

    shellAliases = {
      # nixup is the one that matters: rebuild and switch this host from the
      # flake. The rest are the same operation at other points in the loop.
      nixup = "sudo nixos-rebuild switch --flake ~/Projects/NixClone/nixos-config#coru";
      nixbuild = "sudo nixos-rebuild build --flake ~/Projects/NixClone/nixos-config#coru";
      nixboot = "sudo nixos-rebuild boot --flake ~/Projects/NixClone/nixos-config#coru";
      nixupd = "nix flake update --flake ~/Projects/NixClone/nixos-config";
      nixgc = "sudo nix-collect-garbage -d";
      nixcfg = "cd ~/Projects/NixClone/nixos-config";
    };
  };

  # The wizard-generated p10k prompt, vendored so the shell is fully declarative.
  home.file.".p10k.zsh".source = ../zsh/p10k.zsh;
}
