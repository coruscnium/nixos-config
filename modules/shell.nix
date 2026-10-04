{ lib, pkgs, ... }:

# Zsh: the interactive shell coru lives in.
#
# The login shell itself is set elsewhere -- nixos/users.nix picks pkgs.zsh and
# turns on programs.zsh system-wide. This module owns the *user* side: prompt,
# completion and the nix aliases. ~/.zshrc is generated from here, so the
# hand-written one is replaced; home-manager backs it up to ~/.zshrc.hm-backup
# rather than clobbering it (backupFileExtension is set in flake.nix).
{
  programs.zsh = {
    enable = true;

    # zsh-autocomplete runs compinit itself and owns the completion system, so
    # home-manager's own completion init has to be off (its docs require this on
    # Nix). It also owns Tab and the history keys, so zsh-autosuggestions,
    # zsh-history-substring-search and fzf-tab are deliberately absent -- each of
    # them fights it for the same bindings (see zsh-autocomplete issues #211,
    # #501). syntax-highlighting is fine: it only needs to load last.
    enableCompletion = false;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    initContent = lib.mkMerge [
      # zsh-autocomplete must be sourced near the top, before anything calls
      # compdef -- it installs its own completion widgets and does its own
      # compinit, which is why enableCompletion is false above.
      (lib.mkOrder 500 ''
        source ${pkgs.zsh-autocomplete}/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
      '')

      # p10k is sourced last, as upstream expects. BOTH lines are required: the
      # theme only *defines* the prompt, and it runs its wizard unless a
      # POWERLEVEL9K_* variable is already set, so ~/.p10k.zsh must be sourced
      # too. The config is vendored at zsh/p10k.zsh and placed as ~/.p10k.zsh
      # below -- to change it, run `p10k configure`, copy the result back over
      # zsh/p10k.zsh, rebuild (the managed ~/.p10k.zsh is a read-only symlink).
      (lib.mkOrder 1300 ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      '')
    ];

    shellAliases = {
      # nixup is the everyday one: rebuild and switch this host from the flake.
      nixup = "sudo nixos-rebuild switch --flake ~/Projects/NixClone/nixos-config#coru";
      nixbuild = "sudo nixos-rebuild build --flake ~/Projects/NixClone/nixos-config#coru";
      nixboot = "sudo nixos-rebuild boot --flake ~/Projects/NixClone/nixos-config#coru";
      nixupd = "nix flake update --flake ~/Projects/NixClone/nixos-config";
      nixgc = "sudo nix-collect-garbage -d";
      nixcfg = "cd ~/Projects/NixClone/nixos-config";
    };
  };

  # System-information fetch for the terminal. home-manager writes its default
  # config; there is no custom one yet.
  programs.fastfetch.enable = true;

  # The wizard-generated p10k prompt, vendored so the shell is fully declarative.
  home.file.".p10k.zsh".source = ../zsh/p10k.zsh;
}
