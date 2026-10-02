{ lib, ... }:

{
  nix.settings = {
    # The whole repo is flake-based, so make flakes a first-class default.
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "coru" ];

    # CachyOS kernel cache (mirrors nix-cachyos-kernel's own nixConfig, so the
    # substituter is trusted even on a fresh clone / first rebuild).
    extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
    extra-trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;
}
