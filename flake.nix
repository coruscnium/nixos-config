{
  description = "coru's NixOS + Home Manager flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # quadcast2s is vendored at ./vendor/quadcast2s, not a flake input -- the old
    # path input contained a space and pinned the flake to this machine.
    chaotic = {
      # CachyOS-on-NixOS bridge: linux-cachyos (incl. znver4), proton-cachyos.
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      # Unvetted; used only as pkgs.nur.repos.<user>.<pkg>.
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      # Applies KDE settings with kwriteconfig at activation -- kdeglobals/kwinrc/
      # plasmarc get rewritten by KDE, so they cannot be store symlinks.
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Declarative flatpak app list -- nixpkgs' flatpak module has no app option.
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs =
    { nixpkgs, home-manager, chaotic, nur, plasma-manager, nix-flatpak, ... }:
    let
      system = "x86_64-linux";

      # `pkgs` is passed explicitly to homeManagerConfiguration, so home-manager
      # ignores its own nixpkgs.config -- package config (unfree, overlays) MUST
      # live here.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import ./pkgs { quadcast2sSrc = ./vendor/quadcast2s; })
          chaotic.overlays.default
          nur.overlays.default
        ];
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      homeConfigurations."coru" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./home.nix
          ./modules
          plasma-manager.homeModules.plasma-manager
        ];
      };

      nixosConfigurations =
        let
          common = [
            home-manager.nixosModules.home-manager
            nix-flatpak.nixosModules.nix-flatpak

            # Without the nyx cache every nyx package (incl. the CachyOS kernel)
            # builds from source.
            chaotic.nixosModules.nyx-cache

            {
              # Same overlays as the standalone config, so store paths match --
              # notably pkgs.usb-port-power-cycle, which a sudoers rule and a
              # wrapper both pin.
              nixpkgs.overlays = [
                (import ./pkgs { quadcast2sSrc = ./vendor/quadcast2s; })
                chaotic.overlays.default
                nur.overlays.default
              ];
              nixpkgs.config.allowUnfree = true;

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                # Real files exist where home-manager wants to symlink; move them
                # aside instead of aborting activation.
                backupFileExtension = "hm-backup";

                users.coru.imports = [
                  ./home.nix
                  ./modules
                  plasma-manager.homeModules.plasma-manager
                ];
              };
            }
          ];

          mkNixos = extra: nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ ./nixos ] ++ extra ++ common;
          };
        in
        {
          coru = mkNixos [ ];
          coru-iso = mkNixos [ ./nixos/iso.nix ];
        };
    };
}
