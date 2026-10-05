# Local packages that have no nixpkgs equivalent.
#
# Imported as an overlay in flake.nix. Scripts live in ./scripts.nix so that
# modules/services.nix can reference the same store paths.
{ equibopPkgs }:
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

  # -------------------------------------------------------------------- equibop
  # 3.3.0 rewrote screen-share capture onto venmic 7.x, which broke Wayland
  # sharing. Held at the last venmic 6.1.0 build (3.2.2) by building it from the
  # pinned nixpkgs-equibop input in flake.nix.
  equibop = equibopPkgs.equibop;
}
