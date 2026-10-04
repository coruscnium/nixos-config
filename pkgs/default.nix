# Local packages that have no nixpkgs equivalent.
#
# Imported as an overlay in flake.nix. Scripts live in ./scripts.nix so that
# modules/services.nix can reference the same store paths.
{ quadcast2sSrc }:
final: prev:
let
  lib = prev.lib;

  # nixpkgs' glfw is 3.4; pin 3.3.10 for mangohud (see the override below).
  glfw33 = prev.glfw.overrideAttrs (o: {
    version = "3.3.10";
    src = prev.fetchFromGitHub {
      owner = "glfw";
      repo = "GLFW";
      rev = "3.3.10";
      hash = "sha256-kTRXsfQ+9PFurG3ffz0lwnITAYAXtNl3h/3O6FSny5o=";
    };
    # nixpkgs' postPatch rewrites Wayland dlopen paths in a file the 3.3.x tree
    # does not have.
    postPatch = "";
  });
in
(import ./scripts.nix final prev)
// (import ./wallpaper-engine.nix final prev)
// {
  cherry-studio = prev.callPackage ./cherry-studio.nix { pkgs = prev; };
  beautysolar = prev.callPackage ./beautysolar.nix { };
  # System-wide Carl suite for the Plasma Login Manager greeter, which cannot see
  # coru's home.
  carl-theme = prev.callPackage ./carl-theme.nix { themesDir = ../themes; };

  # ----------------------------------------------------------------- quadcast2s
  # RGB lighting for the HyperX QuadCast 2 S. Source is a local checkout passed
  # from flake.nix -- swap for fetchFromGitHub once it has a public remote.
  quadcast2s = prev.python3Packages.buildPythonApplication rec {
    pname = "quadcast2s";
    version = "0.2.0";
    pyproject = true;

    src = quadcast2sSrc;

    build-system = [ prev.python3Packages.setuptools ];
    dependencies = [
      prev.python3Packages.pyusb
      prev.python3Packages.pyside6
    ];

    doCheck = false;   # upstream tests want a real microphone

    # The checkout carries stale build artifacts whose wheels declare the same
    # console script, so the installer would write bin/quadcast2s twice.
    postPatch = ''
      rm -rf dist build src/*.egg-info
    '';

    postInstall = ''
      appid=xyz.coruscnium.quadcast2s

      install -Dm644 udev/70-quadcast2s.rules \
        $out/lib/udev/rules.d/70-quadcast2s.rules

      install -Dm644 desktop/$appid.desktop \
        $out/share/applications/$appid.desktop
      install -Dm644 desktop/$appid.metainfo.xml \
        $out/share/metainfo/$appid.metainfo.xml
      install -Dm644 desktop/quadcast2s.svg \
        $out/share/icons/hicolor/scalable/apps/quadcast2s.svg

      install -Dm644 LICENSE $out/share/licenses/$pname/LICENSE
      install -Dm644 README.md $out/share/doc/$pname/README.md
      for doc in docs/*.md; do
        install -Dm644 "$doc" $out/share/doc/$pname/$(basename "$doc")
      done

      # Reference copies only -- real units come from modules/services.nix.
      install -Dm644 systemd/quadcast2s.service \
        $out/share/doc/$pname/quadcast2s.service
      install -Dm644 systemd/quadcast2s-hotplug.service \
        $out/share/doc/$pname/quadcast2s-hotplug.service
    '';

    meta = {
      description = "RGB lighting control for the HyperX QuadCast 2 S microphone";
      homepage = "https://github.com/Coruscnium/quadcast2s";
      license = lib.licenses.agpl3Only;
      mainProgram = "quadcast2s";
      platforms = lib.platforms.linux;
    };
  };

  # ----------------------------------------------------------------- reigntweak
  # Elden Ring: Nightreign ultrawide / 60 FPS patcher, built from source (plain
  # C++17 + pthread); upstream's prebuilt binary is not used.
  reigntweak = prev.stdenv.mkDerivation {
    pname = "reigntweak";
    version = "unstable-2026-04-18";

    src = prev.fetchFromGitHub {
      owner = "Minksh";
      repo = "ReignTweak";
      rev = "6f999c4f5c2483bed73c2cce715ebeee4a721d8a";
      hash = "sha256-Lt8++TRIFnsG6h5PDNwBqTIPAePaYV2mTCSukdjZcjY=";
    };

    buildPhase = ''
      runHook preBuild
      $CXX -std=c++17 reigntweak.cpp fps_patch.cpp ultrawide_patch.cpp \
        depth_buffer_patch.cpp -o reigntweak -lpthread
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 reigntweak $out/bin/reigntweak
      runHook postInstall
    '';

    meta = {
      description = "Ultrawide and 60 FPS patcher for Elden Ring: Nightreign";
      homepage = "https://github.com/Minksh/ReignTweak";
      license = lib.licenses.unfree; # no license declared upstream
      platforms = [ "x86_64-linux" ];
    };
  };

  # ------------------------------------------------------------------- mangohud
  # Pinned to glfw 3.3.10: against nixpkgs' glfw 3.4 mangoapp's X11 init fails
  # ("X11: Platform not initialized") and it segfaults, so the HUD never shows
  # (upstream MangoHud#1261). Overriding mangohud, not glfw, keeps every other
  # glfw consumer on 3.4. Both consumers pick this up: programs.mangohud and
  # programs.steam.extraPackages.
  mangohud = prev.mangohud.override { glfw = glfw33; };
}
