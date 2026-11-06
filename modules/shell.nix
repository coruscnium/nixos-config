{ lib, pkgs, ... }:

# Zsh: prompt, completion and nix aliases. ~/.zshrc is generated from here.
let
  # Switch, but take the GitHub copy first when the pull cannot lose anything:
  # clean tracked tree, strictly behind origin, no local commits. A dirty tree,
  # a diverged branch or an unreachable remote all fall back to switching the
  # local tree, which is what nixup did before. This never stashes, rebases or
  # merges -- a pull that quietly rewrote in-flight work would be worse than a
  # build that is a day old.
  nixup = pkgs.writeShellApplication {
    name = "nixup";
    runtimeInputs = [
      pkgs.git
      pkgs.nh
    ];
    text = ''
      repo="$HOME/Projects/NixClone/nixos-config"
      cd "$repo"

      branch=$(git rev-parse --abbrev-ref HEAD)
      if [[ "$branch" == "HEAD" ]]; then
        echo "nixup: detached HEAD, switching the local tree" >&2
      elif ! git fetch --quiet origin; then
        echo "nixup: cannot reach origin, switching the local tree" >&2
      elif ! git rev-parse --verify --quiet "refs/remotes/origin/$branch" >/dev/null; then
        echo "nixup: no origin/$branch to pull from, switching the local tree" >&2
      else
        ahead=$(git rev-list --count "origin/$branch..HEAD")
        behind=$(git rev-list --count "HEAD..origin/$branch")
        dirty=$(git status --porcelain --untracked-files=no)

        if [[ -n "$dirty" ]]; then
          if (( behind > 0 )); then
            echo "nixup: uncommitted changes, skipping the pull (origin/$branch is $behind ahead)" >&2
            echo "nixup: commit or stash them, or run 'git pull' yourself, to take the update" >&2
          else
            echo "nixup: uncommitted changes, and nothing to pull from origin/$branch" >&2
          fi
        elif (( behind == 0 && ahead == 0 )); then
          echo "nixup: up to date with origin/$branch" >&2
        elif (( behind == 0 )); then
          echo "nixup: local is $ahead commit(s) ahead of origin/$branch, nothing to pull" >&2
        elif (( ahead > 0 )); then
          echo "nixup: diverged from origin/$branch ($ahead ahead, $behind behind), skipping the pull" >&2
        elif git merge --ff-only --quiet "origin/$branch"; then
          echo "nixup: fast-forwarded $behind commit(s) from origin/$branch" >&2
        else
          # git refuses when a file arriving from origin would land on an
          # untracked one of the same name.
          echo "nixup: fast-forward blocked by untracked files, switching the local tree" >&2
        fi
      fi

      exec nh os switch "$repo" "$@"
    '';
  };
in
{
  programs.zsh = {
    enable = true;

    # zsh defaults to NOT treating `#` as a comment in interactive shells, so an
    # inline `# note` runs as a command and a bare `v=1  # note` assignment is lost.
    # INTERACTIVE_COMMENTS makes `#` start a comment interactively, as in bash.
    setOptions = [ "INTERACTIVE_COMMENTS" ];

    # zsh-autocomplete runs compinit itself and owns the completion system, so
    # home-manager's completion init must be off. It also owns Tab and the arrow
    # keys, so history-substring-search / fzf-tab are absent -- each rebinds what
    # it already binds. Autosuggestions is the exception: it binds no key of its
    # own, and upstream says the two coexist (discussion #456).
    enableCompletion = false;

    # zsh-autocomplete is a completion *menu*, not a history hint: while you type
    # it completes commands and paths from compsys, and it only reaches into
    # history through the up-arrow widget. zsh-autosuggestions is what puts the
    # grey ghost text from history under the cursor, accepted with Right/Ctrl-E.
    # Home-manager sources it at order 700 -- after autocomplete (500) and before
    # syntax highlighting (1200) -- which is the order it needs.
    autosuggestion = {
      enable = true;
      # The plugin default fg=8 is near-invisible on p10k's dark palette.
      highlight = "fg=244";
    };
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

      # CUA motions. Konsole's shipped keytab (data/keyboard-layouts/default.keytab,
      # the "-Shift+AnyMod" rows) sends \E[1;5X for Ctrl+arrow and \E[1;6X for
      # Ctrl+Shift+arrow, and zsh leaves both unbound -- "undefined-key", so they
      # did nothing at all. Ctrl+Up/Down jump the ends of the line because the
      # plain arrows already walk history.
      (lib.mkOrder 600 ''
        bindkey '^[[1;5D' backward-word
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5A' beginning-of-buffer
        bindkey '^[[1;5B' end-of-buffer

        # Ctrl+Shift+arrows extend a selection over the command line, the shell-side
        # half of CUA. ZLE's region is what draws the reverse-video highlight, and
        # the first press has to set the mark or the selection has no anchor. One
        # function covers all four: WIDGET names the entry that fired, the array
        # says which motion that entry runs. This selects inside the input line --
        # selecting command *output* is Konsole's own mode, Ctrl+Shift+D.
        typeset -A _cua_select_motion=(
          _cua-select-left       backward-word
          _cua-select-right      forward-word
          _cua-select-up         beginning-of-buffer
          _cua-select-down       end-of-buffer
          _cua-select-char-left  backward-char
          _cua-select-char-right forward-char
        )
        _cua-select() {
          (( REGION_ACTIVE )) || zle set-mark-command
          zle $_cua_select_motion[$WIDGET]
        }
        for widget in ''${(k)_cua_select_motion}; do
          zle -N $widget _cua-select
        done
        bindkey '^[[1;6D' _cua-select-left
        bindkey '^[[1;6C' _cua-select-right
        bindkey '^[[1;6A' _cua-select-up
        bindkey '^[[1;6B' _cua-select-down

        # Shift+arrows, one character or one line at a time. Only reachable with
        # the CUA keytab selected in the Konsole profile: stock Konsole sends
        # nothing for shift+arrow, because its defaults spend shift+left/right
        # on previous/next tab and shift+up/down on scrolling.
        bindkey '^[[1;2D' _cua-select-char-left
        bindkey '^[[1;2C' _cua-select-char-right
        bindkey '^[[1;2A' _cua-select-up
        bindkey '^[[1;2B' _cua-select-down
      '')

      # p10k last. Both lines needed: the theme only defines the prompt and runs
      # its wizard unless a POWERLEVEL9K_* var is set, so ~/.p10k.zsh is sourced
      # too. Edit zsh/p10k.zsh -- the installed ~/.p10k.zsh is a read-only symlink.
      (lib.mkOrder 1300 ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      '')
    ];

    # nh wraps nixos-rebuild and prints a readable generation diff (packages
    # added/removed, version bumps, closure delta). NH_FLAKE is set by the
    # programs.nh module, but pass the path so the alias stands alone.
    shellAliases = {
      # nixup is a script, not an alias -- it fast-forwards from origin first.
      # See the writeShellApplication at the top of this file.
      nixbuild = "nh os build ~/Projects/NixClone/nixos-config";
      nixboot = "nh os boot ~/Projects/NixClone/nixos-config";
      # Every source set, in the order they have to run: tag-pinned flake inputs
      # (butter -- a tag never moves, so `nix flake update` cannot bump it),
      # then flake.lock inputs, then the nvfetcher AppImages (cherry-studio,
      # elegooslicer, astra) that neither of the other two can see. The
      # subshell keeps your cwd put -- nvfetcher writes _sources/ relative to
      # cwd, so it has to run inside the repo.
      nixupd = "(cd ~/Projects/NixClone/nixos-config && ./scripts/bump-release-tags && nix flake update && nix run nixpkgs#nvfetcher)";
      # nh raises its own elevation (doas/sudo/run0/pkexec), so no `sudo` here.
      # Keeps 3 generations per profile (nh defaults to 1) for rollback headroom.
      nixgc = "nh clean all -k 3";
      nixcfg = "cd ~/Projects/NixClone/nixos-config";
    };
  };

  home.packages = [ nixup ];

  # Konsole's stock table never lets shift+arrow reach the shell, so the bindkeys
  # above are dead keys until this layout is picked in the profile's Keyboard
  # list. The file is read-only on purpose -- Konsole copies it into
  # ~/.local/share/konsole/ when the user edits a layout in the GUI, and that
  # copy is what the profile then points at.
  home.file.".local/share/konsole/CUA.keytab".source = ../konsole/CUA.keytab;

  # zsh-autocomplete installs the dist chpwd_recent_dirs hook, whose cache lives
  # under ${XDG_DATA_HOME:-~/.local/share}/zsh/ -- but nothing creates that dir, so
  # the write on every cd fails ("no such file or directory"). Creating it is the
  # whole fix: the hook then writes the file itself.
  home.activation.zshRecentDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "''${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
  '';

  programs.fastfetch.enable = true;

  # Frecency `cd`: `z <fragment>` jumps to the dir you actually visit. Binds only
  # z/zi, so it does not contend with zsh-autocomplete.
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file.".p10k.zsh".source = ../zsh/p10k.zsh;
}
