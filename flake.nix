{
  description = "NixOS on the ASUS ProArt PX13 (HN7306WU)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # CachyOS kernels are not in nixpkgs. `overlays.pinned` uses this flake's
    # own prebuilt package set, which is what its lantian/attic binary cache
    # covers — so we substitute kernels instead of compiling them.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

    # User-level packages & dotfiles. `master` pairs with nixos-unstable.
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NUR supplies packages missing from nixpkgs (e.g. Brave Origin) and is
    # CI-updated, so it tracks along with `nix flake update`.
    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ASUS DialPad driver (touchpad-corner virtual dial). Not in nixpkgs; ships
    # its own NixOS module + overlay.
    asus-dialpad-driver = {
      url = "github:asus-linux-drivers/asus-dialpad-driver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, ... }@inputs:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Don't silently clobber files that already exist in $HOME.
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.coru = import ./home/coru.nix;
          }
        ];
      };
    };
}
