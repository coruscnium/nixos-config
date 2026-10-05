# AGENTS.md — nixos-config

Instructions for any AI agent working in this repository. Read it before editing. It encodes
conventions that were expensive to learn — following them is the difference between a working build
and a broken boot.

## Ground rules

- **This configures a real machine.** A wrong change can make it unbootable. Prefer the smallest
  correct change; do not restructure working code to make a small edit prettier.
- **Never `git commit`, `git push`, or `nixos-rebuild switch` unless the user explicitly asks in that
  moment.** Draft the change, prove it builds, and hand it back. (No `sudo` on this machine anyway.)
- **Attribute commits to the user, never to an AI.** When asked to commit, add no `Co-Authored-By`,
  no "Generated with", no Claude/AI contributor trailer of any kind. The work lands under the user's
  name, because it is their repo.
- **Prefix `nix`, `git` (https), and `curl` with `env -u LD_LIBRARY_PATH`.** The host app exports an
  `LD_LIBRARY_PATH` carrying a GnuTLS libcurl that shadows the OpenSSL one; without the prefix these
  commands die with `version 'CURL_OPENSSL_4' not found`. SSH git is unaffected.
- **Verify every package and option exists before naming it** — via the `nix` MCP tool
  (`action="search"` then `action="info"`) or `env -u LD_LIBRARY_PATH nix search nixpkgs#<term>`.
  Never write an attribute name from memory.
- **The MCP tool knows upstream nixpkgs only.** It does not see this repo's overlays (chaotic/nyx,
  NUR) or the custom packages in `pkgs/`. If something is missing from it, check those sources before
  concluding it does not exist.
- **Check before adding anything.** It may already be installed, or be deliberately excluded. Scan
  `modules/`/`nixos/` for the package; the vault's packaging ledger holds the exclusion list.

## Directory contract

| Dir | Level | What belongs |
|---|---|---|
| `modules/` | Home Manager — per-user | `home.packages`, `home.file`, `systemd.user.*`, `programs.*` |
| `nixos/` | NixOS — machine | `boot`, `fileSystems`, `services.*`, `users.users`, `environment.systemPackages` |
| `pkgs/` | overlay | custom packages; `default.nix` is the overlay function |
| `scripts/` | raw shell | wrapped into derivations by `pkgs/scripts.nix` |
| `themes/` | vendored | the Carl KDE/GTK theme suite |
| `_sources/` | **generated** | nvfetcher output — never hand-edit |

`modules/` is what the user owns; `nixos/` is the machine. Both `modules/default.nix` and
`nixos/default.nix` are pure `imports = [ ... ]` aggregators.

## Where a new thing goes, in preference order

1. **In nixpkgs** → `home.packages` in the matching `modules/<category>.nix`. Admin/system tooling →
   `environment.systemPackages` in `nixos/system.nix`.
2. **In chaotic-nyx** → top-level `pkgs`.
3. **In NUR** → `pkgs.nur.repos.<user>.<pkg>` only (it does not merge into `pkgs`). Unvetted.
4. **Custom package** → new `pkgs/<name>.nix`, called from `pkgs/default.nix`.
5. **nvfetcher-pinned upstream** → root-level table in `nvfetcher.toml`, then `nix run nixpkgs#nvfetcher`.
6. **Vendored** → drop the tree in and **git-track it**.

## Hard rules — do not break these

1. **Only git-tracked files reach the store.** The flake copies tracked files into `/nix/store`, so
   `themes/` must stay tracked. `.gitignore`
   ignores only `result*` and editor cruft — keep it that way.
2. **`pkgs.usb-port-power-cycle` is identity-critical.** A sudoers rule (`nixos/users.nix`) and a
   watchdog wrapper both pin its store path. Do not redefine it elsewhere.
3. **Package config lives in `flake.nix`, not `~/.config/nixpkgs`.** Because `pkgs` is passed
   explicitly to `homeManagerConfiguration`, home-manager ignores its own `nixpkgs.config`.
   `allowUnfree`, overlays, and `permittedInsecurePackages` must be in `flake.nix`.
4. **Keep the Limine settings on `lib.mkDefault`** in `nixos/boot.nix` — never `mkForce` them.
   Same caution for `efiSupport`, `efiInstallAsRemovable`, `maxGenerations`, `canTouchEfiVariables`.
5. **`rootflags=` is derived** from `fileSystems."/".options`; never hardcode it, and do not add
   `subvol=@` or `x-initrd.mount` to `/`.
6. **plasma-manager: leave `lookAndFeel` unset** — it clashes with the explicit theme block.
7. **`QT_QPA_PLATFORMTHEME` must be `"kde"`** (`nixos/desktop.nix`); `qt6ct` causes the half-light /
   half-dark bug.
8. **`environment.pathsToLink`**: `/share/icons` is deliberately absent (a module already adds it).
9. **`_sources/generated.*` is nvfetcher output** — never hand-edit. nvfetcher table names go at the
   **root** of `nvfetcher.toml`, not under `[sources.*]`.
10. **`sshd` stays off by default** — a listening sshd is a decision, not a default.
11. **Never install the same package in both `modules/` and `nixos/`.** The ledger's rule: nothing
    forgotten, nothing installed twice.
12. **The nyx cache module is required.** `chaotic.nixosModules.nyx-cache` must stay enabled, or every
    nyx package (including the CachyOS kernel) is built from source instead of downloaded.

## Build and verify

```bash
cd ~/Projects/NixClone/nixos-config

env -u LD_LIBRARY_PATH nix flake show --no-write-lock-file       # evaluate all outputs
env -u LD_LIBRARY_PATH nixos-rebuild build --flake .#coru        # build, activate nothing
env -u LD_LIBRARY_PATH nix fmt                                   # format -- run after editing .nix
```

A change is not done until it evaluates. `build` produces `./result` and changes nothing about the
running system — that is the proof.

Run `nix fmt` after editing `.nix` files. The flake's `formatter` (treefmt + nixfmt, RFC style, config
in `treefmt.toml`) is authoritative for layout — do not hand-format. `_sources/` is excluded.

## Documentation

This repo carries only this file and the config. The two "why" documents — the packaging ledger and
the CachyOS→NixOS / systemd-boot→Limine runbook — live in Vesta's vault, not the repo.
