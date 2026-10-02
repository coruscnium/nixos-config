{
  description = "NixOS on the ASUS ProArt PX13 (HN7306WU)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # CachyOS kernels are not in nixpkgs. `overlays.pinned` uses this flake's
    # own prebuilt package set, which is what its lantian/attic binary cache
    # covers — so we substitute kernels instead of compiling them.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

    # User-level packages & dotfiles. Pin to the release matching nixpkgs.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
