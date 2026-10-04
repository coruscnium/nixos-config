{ pkgs, ... }:

# File management, encryption, disk tooling.
{
  home.packages = with pkgs; [
    gocryptfs
    sirikali
    trash-cli
    ripgrep
    gum
    duf
    compsize
    xdg-ninja
    gparted
    btrfs-assistant
    plocate

    # Modern CLI replacements for find/cat/ls, plus a fuzzy finder. Added at
    # Coru's request for shell ergonomics. They land in coru's per-user profile,
    # which is also the PATH the agent's shell runs on, so both get them.
    fd                                 # find
    bat                                # cat, with syntax highlighting
    eza                                # ls, with git status and tree views
    fzf                                # fuzzy finder
  ];
}
