# nutmeg -- Roblox bootstrapper (frolleks/nutmeg). Downloads Roblox's macOS
# client, keeps it current, and starts it through rosemary.
#
# Not in nixpkgs. Pure Python + GTK 4, and upstream declares no Python
# dependencies at all -- PyGObject and the toolkit come from the distribution
# (their own flake.nix devShell is python+pygobject3+gtk4+gobject-introspection
# +xdg-utils), so the Nix derivation supplies exactly that.
#
# The repo carries no releases, only `nightly-<date>-<time>` tags cut from main,
# so this pins a rev. Bump: set version + rev, then
#   nix-prefetch-url --unpack https://github.com/frolleks/nutmeg/archive/<rev>.tar.gz
# and convert its base32 to SRI with `nix hash convert --to sri`.
#
# Runtime, found on PATH rather than in the closure -- both present as system
# packages: `rosemary` (the client runner) and `xdg-mime` (from xdg-utils, used
# by `nutmeg install-desktop` to register the roblox: handlers).
{
  lib,
  python3Packages,
  fetchFromGitHub,
  gtk4,
  glib,
  gobject-introspection,
  wrapGAppsHook4,
}:

python3Packages.buildPythonApplication rec {
  pname = "nutmeg";
  version = "0.1.0-unstable-2026-10-13";

  pyproject = true;

  src = fetchFromGitHub {
    owner = "frolleks";
    repo = "nutmeg";
    rev = "a19421648679916fc6d65cea06899acded2609dc";
    hash = "sha256-M7EGRPJzV+sRuAseOdYFLfOY78b1QaiAoQqBO/ezkgc=";
  };

  # `nutmeg install-desktop` writes its Exec as `<sys.executable> -m nutmeg`,
  # which under Nix is the bare shared interpreter -- no PyGObject on its path
  # and no GI_TYPELIB_PATH, so the entry it writes dies with
  # `ModuleNotFoundError: No module named 'gi'`. Repoint it at the launcher.
  patches = [ ./nutmeg-desktop-entry.patch ];

  build-system = [ python3Packages.setuptools ];

  # wrapGAppsHook4 is what puts gtk4's Gtk-4.0 typelib on GI_TYPELIB_PATH;
  # without it `from gi.repository import Gtk` fails at import.
  nativeBuildInputs = [
    gobject-introspection
    wrapGAppsHook4
  ];

  buildInputs = [
    glib
    gtk4
  ];

  propagatedBuildInputs = [ python3Packages.pygobject3 ];

  pythonImportsCheck = [ "nutmeg" ];

  meta = {
    description = "Roblox bootstrapper that runs the macOS client through rosemary";
    homepage = "https://github.com/frolleks/nutmeg";
    license = lib.licenses.gpl3Only;
    mainProgram = "nutmeg";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
