{
  description = "coru's NixOS + Home Manager flake";

  inputs = {
    # Held at the last rev shipping Plasma 6.8.0. 6.8.1 regressed mixed-refresh
    # compositing (KDE bug 527668): Overview and fullscreen animations stutter on
    # 240 + 144 + 60 Hz while every counter reads idle, and disabling the two
    # slower outputs on 6.8.1 makes it smooth again. The whole rev is pinned, not
    # just kdePackages -- swapping only the KDE scope drags Qt 6.11 against our
    # 6.12 and rebuilds the entire Qt/KF stack from source, since no cache has
    # that combination. A rev-pinned URL also stops `nix flake update` moving it;
    # go back to nixos-unstable once 6.8.2 is in.
    nixpkgs.url = "github:nixos/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    chaotic = {
      # CachyOS-on-NixOS bridge. The linux-cachyos kernel was dropped for the
      # stock one (nixos/boot.nix); proton-cachyos is still wanted.
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

    # CoruFrame -- Coru's own Warframe companion (relic HUD, inventory ledger,
    # market tools). Ships packages plus NixOS/home-manager modules. Its Rust and
    # Tauri builds are pinned by cargoHash/pnpmDeps, so it must follow our nixpkgs
    # or the pinned hashes break.
    #
    # Tracks the `nightly` branch: the lockfile holds a commit, so "latest" means
    # `nix flake update coruframe` before rebuilding -- a plain build keeps
    # whatever commit was last locked. Release tags were the pin until
    # 2026-10-28; nightly still carries zbus 5, so it is not the v1.0.0 breakage.
    coruframe = {
      url = "github:coruscnium/CoruFrame/nightly";
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
      coruframe,
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
          windscribe.overlays.default
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
          coruframe.homeManagerModules.default
        ];
      };

      nixosConfigurations =
        let
          common = [
            windscribe.nixosModules.default
            home-manager.nixosModules.home-manager
            nix-flatpak.nixosModules.nix-flatpak

            # Without the nyx cache every nyx package (proton-cachyos) builds
            # from source.
            chaotic.nixosModules.nyx-cache

            {
              # Same overlays as the standalone config, so store paths match --
              # notably pkgs.usb-port-power-cycle, which a sudoers rule and a
              # wrapper both pin.
              nixpkgs.overlays = [
                (import ./pkgs { inherit equibopPkgs rosemaryPkg; })
                windscribe.overlays.default
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
              };
            }
          ];

          # Each host supplies its own machine modules and its own user profile --
          # that split is the point of hosts/. The flake inputs a user profile needs
          # (plasma-manager, rosemary, coruframe) are in lexical scope here, which
          # is why the list is passed in rather than written inside each host.
          mkNixos =
            { extra, hm }:
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = extra ++ common ++ [ { home-manager.users.coru.imports = hm; } ];
            };
        in
        {
          coru = mkNixos {
            extra = [ ./hosts/coru ];
            hm = [
              ./home.nix
              ./modules
              plasma-manager.homeModules.plasma-manager
              rosemary.homeManagerModules.default
              coruframe.homeManagerModules.default
            ];
          };

          # Attribute names must equal networking.hostName (hosts/*/default.nix):
          # `nh os switch` and `nixos-rebuild --flake .` both infer the attribute
          # from the machine's hostname, so a short label like `laptop` makes
          # every one of them fail with "does not provide attribute".
          coru-laptop = mkNixos {
            extra = [ ./hosts/laptop ];
            hm = [
              ./home.nix
              ./hosts/laptop/hm.nix
              plasma-manager.homeModules.plasma-manager
            ];
          };
        };
    };
}
