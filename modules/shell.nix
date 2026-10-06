{ lib, pkgs, ... }:

# Zsh: prompt, completion and nix aliases. ~/.zshrc is generated from here.
{
  programs.zsh = {
    enable = true;

    # zsh defaults to NOT treating `#` as a comment in interactive shells, so an
    # inline `# note` runs as a command and a bare `v=1  # note` assignment is lost.
    # INTERACTIVE_COMMENTS makes `#` start a comment interactively, as in bash.
    setOptions = [ "INTERACTIVE_COMMENTS" ];

    # zsh-autocomplete runs compinit itself and owns the completion system, so
    # home-manager's completion init must be off. It also owns Tab and the history
    # keys, so autosuggestions / history-substring-search / fzf-tab are absent --
    # each fights it for the same bindings.
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
      # p10k instant prompt: MUST come first. Guarded so it is safe before the
      # dump exists.
      (lib.mkOrder 100 ''
        if [[ -r ''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh ]]; then
          source ''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh
        fi
      '')

      # zsh-autocomplete must load before anything calls compdef.
      (lib.mkOrder 500 ''
        source ${pkgs.zsh-autocomplete}/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
      '')

      # p10k last. Both lines needed: the theme only defines the prompt and runs
      # its wizard unless a POWERLEVEL9K_* var is set, so ~/.p10k.zsh is sourced
      # too. Edit zsh/p10k.zsh -- the installed ~/.p10k.zsh is a read-only symlink.
      (lib.mkOrder 1300 ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      '')
    ];

    shellAliases = {
      nixup = "sudo nixos-rebuild switch --flake ~/Projects/NixClone/nixos-config#coru";
      nixbuild = "sudo nixos-rebuild build --flake ~/Projects/NixClone/nixos-config#coru";
      nixboot = "sudo nixos-rebuild boot --flake ~/Projects/NixClone/nixos-config#coru";
      nixupd = "nix flake update --flake ~/Projects/NixClone/nixos-config";
      nixgc = "sudo nix-collect-garbage -d";
      nixcfg = "cd ~/Projects/NixClone/nixos-config";
    };
  };

  programs.fastfetch.enable = true;

  home.file.".p10k.zsh".source = ../zsh/p10k.zsh;
}
