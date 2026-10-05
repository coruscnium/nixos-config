# Packaging ledger

What is deliberately *not* in the category modules, and why. The point of this
file is that nothing gets forgotten and nothing gets installed twice.

## How updates work

| Thing | Update mechanism |
|---|---|
| nixpkgs, home-manager, chaotic-nyx, NUR | `nix flake update` (bumps flake.lock) |
| Cherry Studio | `nix run nixpkgs#nvfetcher` — re-resolves `_sources/generated.nix` |
| NUR packages (e.g. `forkprince.nuvio`) | ride the NUR input, so `nix flake update` |
| OctoEverywhere container image | `./nixos/update-octoeverywhere.sh --rebuild` |
| `reigntweak` | bump `rev` + `hash` in `pkgs/default.nix` — `nix-prefetch-github Minksh ReignTweak --rev <sha>` |
| `themes/` (Carl) | manual — pling.com serves a bot challenge, so there is no fetchable URL |
| Flatpaks | declarative — `services.flatpak.packages` via nix-flatpak; set `services.flatpak.update.onActivation = true` to update on rebuild |
| AppImages | manual (that is the cost of being an AppImage) |
| `equibop` | **pinned** at 3.2.2 — `nixpkgs-equibop` flake input at the 3.2.2 rev; an exact-rev input cannot be moved by `nix flake update` |

**Pinned single package.** `equibop` is held at 3.2.2 (venmic 6.1.0) because
3.3.0 rewrote Wayland screen-share capture onto venmic 7.x, which broke sharing.
The pin is a second nixpkgs input, `nixpkgs-equibop` (`flake.nix`), pinned to the
3.2.2 rev; `pkgs/default.nix` sets `equibop = equibopPkgs.equibop`. Unpin by
deleting the input + that one line once a venmic-7 build works.

## A. Becomes a NixOS system module (not a home package)

    plasma6            -> services.desktopManager.plasma6.enable
    sddm               -> services.displayManager.sddm.enable
    power-profiles     -> services.power-profiles-daemon.enable
    zram               -> zramSwap.enable
    limine             -> boot.loader.limine.enable      (maxGenerations matters:
                          the 1 GiB ESP holds ~3 generations comfortably)
    pipewire           -> services.pipewire.enable
    networkmanager     -> networking.networkmanager.enable
    bluetooth          -> hardware.bluetooth.enable   (bluez only). blueman is
                          NOT enabled -- Bluetooth is managed with Plasma's own
                          applet
    printing           -> services.printing.enable
    brscan5            -> Brother scanner driver/udev (unfree .deb repack)
    v4l2loopback       -> boot.kernelModules=["v4l2loopback"] +
                          boot.extraModulePackages=[...v4l2loopback]
    kdePackages.kscreen-> supplies kscreen-doctor
    steam/gamemode     -> programs.steam / programs.gamemode
    mangohud           -> programs.mangohud (home-manager -- there is NO NixOS
                          module for it) + pkgs.mangohud seeded into the Steam
                          FHS via programs.steam.extraPackages
    ollama             -> services.ollama.enable
    syncthing          -> services.syncthing.enable
    ydotool            -> programs.ydotool.enable
    snapper            -> services.snapper.configs  (generations cover the
                          system; snapshots are still needed for data)
    rocm/hip/opencl    -> hardware.graphics + rocmPackages
    windows-drives     -> /mnt/ssd2 and /mnt/ssd3 must keep their exact paths
                          or the Steam libraries break

## B. Available from other repositories

**chaotic-nyx** (`github:chaotic-cx/nyx/nyxpkgs-unstable`) — the CachyOS bridge.
Provides the `linux-cachyos` family with per-variant configs including
**znver4** (this machine's target), `nvidia-cachyos`, `proton-bin` with the
CachyOS manifests, `ananicy-cpp-rules`, `bpftools-full`, `low-latency-layer`,
`luxtorpeda`, `vulkan-versioned`, and `*-git` builds.
Confirmed present in the merged pkgs: `proton-cachyos`, `linuxPackages_cachyos`.
Caveat: nyx issue #1158 — `linuxPackages_cachyos` was broken against *stable*
nixpkgs. This config is on nixos-unstable, which is the supported case.

**NUR** (`github:nix-community/NUR`) — verified by grepping the complete
`nur-combined` tree (57,558 paths, untruncated):
`mio.zen-browser`, `cmdorexe.waterfox`, `vladexa.proton-cachyos`,
`forkprince.nuvio` (in use), `ivar.ryujinx`.
NUR does **not** merge into pkgs — use `pkgs.nur.repos.<user>.<pkg>`.
It is user-contributed and unvetted: `ivar.ryujinx` currently **fails to
evaluate** because it needs `dotnet-sdk_5`, which nixpkgs removed. Probe each
package individually before trusting it.

**Not found in nixpkgs, nyx or NUR:** windscribe, cover-thumbnailer, mocktail,
weekbox, hd2arsenal, amethyst-mod-manager, cordial, silex-desktop, lobehub,
anvil-organizer.

**Not packages at all** — runtime artifacts:
- `kwin-karousel`, `kwin-effects-better-blur-dx` -> KWin scripts, installed
  into `~/.local/share/kwin/scripts`
- `spicetify-marketplace` -> installed by `spicetify-cli` into `~/.config/spicetify`
- `wallpaper-engine-kde-plugin`, `plasma6-wallpapers-smart-video-wallpaper-reborn`
  -> CMake/QML projects, buildable from source if wanted
- `btrfsmaintenance` -> covered natively by `services.btrfs.autoScrub`

## C. Custom packages written for this config

    reigntweak   -> pkgs/default.nix. Built from source — github:Minksh/ReignTweak
                    pinned by rev. Plain C++17 against the standard library plus
                    pthread, no external deps.
    octoeverywhere -> nixos/octoeverywhere.nix. Official container image, pinned
                    by digest via dockerTools.pullImage.
    cherry-studio -> pkgs/cherry-studio.nix. nixpkgs has it, but at 1.9.11
                    against our 2.1.4, and the 2.x bump there pins an insecure
                    Electron. We wrap upstream's AppImage with the version and
                    hash resolved by nvfetcher (nvfetcher.toml -> _sources/).
                    This is also the harness this config is developed in.
                    Its install phase byte-patches app.asar to fix Cherry's own
                    clobbered Wayland global-shortcut flag (see the header note
                    in pkgs/cherry-studio.nix).

                    nvfetcher CANNOT replace the rest of the vendoring:
                      themes/             pling.com serves a bot challenge.
                      scripts/            our own code.

    windscribe   -> NOT PACKAGED, deferred. It is not "just an unpacked .deb":
                    Windscribe publishes its own Arch package, and the payload is
                    a root helper daemon + four more daemons + a systemd system
                    service + a system user/group + a setgid GUI + scripts that
                    take over resolv.conf / systemd-resolved / NetworkManager /
                    nftables + a self-updater. On NixOS the setgid step is
                    impossible (immutable store) and the self-updater fights
                    immutability. Options: (a) native WireGuard configs,
                    (b) ~60 lines of Nix + a system service, (c) keep it outside
                    Nix. Revisit later.

## D. Keep as AppImage in ~/.local/bin (inside $HOME, survives)

Requires `programs.appimage.enable = true;` — NixOS has no `/usr/lib/libfuse*`.
AmethystModManager, WeekBox, HD2Arsenal (your mod managers), bluestar,
elegooslicer, orcaslicer, F-Chat.Horizon, Cordial, Root, Mocktail.
Nuvio is no longer here — it comes from NUR now.

## E. Flatpak (declarative)

Managed with **nix-flatpak** (flake input) — declare apps in
`nixos/services.nix` under `services.flatpak.packages`. The module adds the
flathub remote and installs/removes on activation. `uninstallUnmanaged` stays
off, so flatpaks installed by hand are left alone.

    Sober         -> org.vinegarhq.Sober  (Roblox; Flatpak-only)
    ...the other ten in nixos/services.nix (shelly is NOT here -- see §G)

cherry-studio is NOT a flatpak here — it is packaged in-repo
(pkgs/cherry-studio.nix, built from the upstream AppImage).

## F. Deliberate opt-ins

    ventoy            -> nixpkgs marks ventoy insecure. To accept, add to the
                         `config` block in flake.nix:
                         permittedInsecurePackages = [ "ventoy-1.1.17" ];
    adwaita-qt / qgnomeplatform -> exist, but Kvantum + qt6ct already cover
                         Qt theming on Plasma.
    chromium Widevine -> do NOT use `chromium.override { enableWideVine = true; }`.
                         Changing an argument makes it a cache miss, i.e. a full
                         Chromium source build. brave-origin's .deb already
                         carries Widevine.

## G. Excluded on your instruction

    lock-displays.service, shelly-notifications.service (ALPM-only),
    pwctl-chain@.service (generated by PipeWire Controller), hyphen Hyprland
    remnants (hyprsunset, xdg-desktop-portal-hyprland, hyprpolkitagent), the
    voxtype/deepfilternet experiment, scrcpy/qtscrcpy.
