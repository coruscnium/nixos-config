{
  description = "NixOS on the ASUS ProArt PX13 (HN7306WU)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # CachyOS kernels are not in nixpkgs. `overlays.pinned` uses this flake's
    # own prebuilt package set, which is what its lantian/attic binary cache
    # covers — so we substitute kernels instead of compiling them.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./configuration.nix ];
      };
    };
}
