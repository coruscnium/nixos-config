{
  description = "coru's NixOS + Home Manager flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # equibop 3.3.0 rewrote Wayland screen-share capture onto venmic 7.x, which
    # broke sharing. Held at the last venmic 6.1.0 build (equibop 3.2.2) by exact
    # rev, so `nix flake update` cannot move it.
    nixpkgs-equibop.url = "github:NixOS/nixpkgs/c59305bab2065cfecc4944690d9eedbb56f3a9fa";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      chaotic,
      nur,
      plasma-manager,
      nix-flatpak,
      nixpkgs-equibop,
      ...
    }:
    let
      system = "x86_64-linux";

      # equibop's pinned rev (its build uses venmic 6.1.0 -- see the input above).
      equibopPkgs = import nixpkgs-equibop { inherit system; };

      # `pkgs` is passed explicitly to homeManagerConfiguration, so home-manager
      # ignores its own nixpkgs.config -- package config (unfree, overlays) MUST
      # live here.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import ./pkgs { inherit equibopPkgs; })
          chaotic.overlays.default
          nur.overlays.default
        ];
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      # `nix fmt` -- nixfmt (RFC style) across the tree via treefmt (see ./treefmt.toml).
      formatter.${system} = pkgs.writeShellApplication {
        name = "treefmt";
        runtimeInputs = [
          pkgs.treefmt
          pkgs.nixfmt
        ];
        text = ''exec treefmt --config-file ${./treefmt.toml} "$@"'';
      };

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
                (import ./pkgs { inherit equibopPkgs; })
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

          mkNixos =
            extra:
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [ ./nixos ] ++ extra ++ common;
            };
        in
        {
          coru = mkNixos [ ];
        };
    };
}
