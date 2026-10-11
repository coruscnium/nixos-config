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

    # Windscribe VPN client -- ParkerrDev's community flake (binary .deb repack
    # + NixOS module). Replaced our own windscribe-nix: his module handles the
    # helper's hardcoded PATH and the realpath("/opt/windscribe") check ours did
    # not, and is VM-tested across every protocol.
    windscribe = {
      url = "github:ParkerrDev/nixpkgs-windscribe";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS compatibility layer -- runs macOS binaries on Linux (Wine-shaped, not
    # a launcher). A flake, not in nixpkgs. nixpkgs.follows shares our eval so
    # SDL3 (needs >= 3.4.0) and the Rust toolchain resolve against nixos-unstable;
    # drop the follows if it ever fails to build against our nixpkgs.
    rosemary = {
      url = "github:microlift/rosemary";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      windscribe,
      rosemary,
      ...
    }:
    let
      system = "x86_64-linux";

      # equibop's pinned rev (its build uses venmic 6.1.0 -- see the input above).
      equibopPkgs = import nixpkgs-equibop { inherit system; };

      # Rosemary's CLI (`rosemary` and `default` are the same derivation). Built
      # by its own flake; pkgs/default.nix republishes it as pkgs.rosemary.
      rosemaryPkg = rosemary.packages.${system}.rosemary;

      # `pkgs` is passed explicitly to homeManagerConfiguration, so home-manager
      # ignores its own nixpkgs.config -- package config (unfree, overlays) MUST
      # live here.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import ./pkgs { inherit equibopPkgs rosemaryPkg; })
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
          rosemary.homeManagerModules.default
        ];
      };

      nixosConfigurations =
        let
          common = [
            windscribe.nixosModules.default
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
                (import ./pkgs { inherit equibopPkgs rosemaryPkg; })
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
                # ...and overwrite a stale backup from an earlier collision instead
                # of erroring. KDE periodically rewrites mimeapps.list (a HM-owned
                # symlink) into a real file; that re-triggers the backup on the
                # next activation, and without this the second occurrence collides
                # with the first backup and fails the whole switch.
                overwriteBackup = true;

                users.coru.imports = [
                  ./home.nix
                  ./modules
                  plasma-manager.homeModules.plasma-manager
                  rosemary.homeManagerModules.default
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
