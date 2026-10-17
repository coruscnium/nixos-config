{
  config,
  lib,
  pkgs,
  ...
}:

# Identity, locale, nix daemon settings, admin tooling.
{
  networking.hostName = "coru";

  # Feeds NAME/PRETTY_NAME in /etc/os-release. ID stays "nixos" so fastfetch keeps
  # its snowflake logo. Drop for stock NixOS.
  system.nixos.distroName = "CoruscOS";

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  system.stateVersion = "25.11";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "coru"
    ];
    auto-optimise-store = true;
  };

  # REQUIRED: prebuilt binaries (AppImages, Resolve, LM Studio) need an FHS
  # dynamic loader NixOS does not provide.
  programs.nix-ld.enable = true;

  # nix-ld exposes ONLY the lib dirs of the packages listed here -- never their
  # transitive deps -- so a GUI binary needs its whole closure named. The module
  # default is 14 bare libs; the Unity Editor (VRChat avatar work, launched
  # natively by ALCOM) needs the GTK3/X11/GL stack on top. Its own DT_NEEDED is
  # libGL libX11 libXcursor libXrandr libgtk-3 libgdk-3 libgdk_pixbuf libgio
  # libglib libgobject libudev libxml2.so.2 libz; the rest below is that closure.
  # Verified 2026-10-12 by running the Editor against exactly this set:
  # `NIX_LD_LIBRARY_PATH=<these>/lib Unity -version` -> 2022.3.22f1, exit 0.
  #
  # libxml2 here is 2.15 (soname libxml2.so.16) but the Editor was built against
  # libxml2.so.2 -> libxml2_13. Defining `libraries` REPLACES the module default,
  # so the base set is repeated first.
  programs.nix-ld.libraries = with pkgs; [
    # module default (repeated because defining `libraries` drops it)
    zlib
    zstd
    stdenv.cc.cc
    curl
    openssl
    attr
    libssh
    bzip2
    libxml2
    acl
    libsodium
    util-linux
    xz
    systemd

    # GTK3 + GL
    gtk3
    gdk-pixbuf
    glib
    pango
    cairo
    atk
    harfbuzz
    fontconfig
    freetype
    fribidi
    libpng
    brotli
    pixman
    expat
    graphite2
    libthai
    libdatrie
    libepoxy
    libffi
    pcre2
    libselinux
    json-glib
    tinysparql
    libjpeg_turbo
    libnotify
    gsettings-desktop-schemas
    libglvnd
    # Poiyomi refuses to compile on OpenGL, so the Editor needs Vulkan. Unity
    # dlopens libvulkan.so.1 itself (it is not a DT_NEEDED of the binary), and
    # that loader is the one piece this set lacked -- without it the Editor logs
    # "LoadVulkanLibrary failed to load libvulkan.so.1", falls back to OpenGL,
    # and Poiyomi aborts. The mesa ICDs are already reachable via
    # /run/opengl-driver/share/vulkan/icd.d, so the loader alone closes the gap.
    # vulkan-loader/lib is the loader; it finds libvulkan_radeon.so by absolute
    # path from the ICD json, so no driver package belongs here.
    vulkan-loader
    libxkbcommon
    dbus
    nss
    nspr
    icu
    alsa-lib
    wayland
    libxml2_13

    # X11
    libX11
    libXcursor
    libXrandr
    libXinerama
    libXext
    libXfixes
    libXcomposite
    libXdamage
    libXrender
    libXi
    libXtst
    libXxf86vm
    libxcb
    libXau
    libXdmcp
    libSM
    libICE
    libXScrnSaver
    libxshmfence
  ];

  programs.appimage.enable = true;

  # nh wraps nixos-rebuild and prints a readable generation diff. NH_FLAKE makes
  # `nh os switch` (and `nh home switch`) resolve this flake with no argument.
  programs.nh = {
    enable = true;
    flake = "/home/coru/Projects/NixClone/nixos-config";
  };

  # comma -- `, <cmd>` runs any nixpkgs binary without installing it. Installing
  # it here (not in modules/) means the binary and its zsh command-not-found
  # handler come from one place. The handler is the flake-friendly replacement
  # for programs.command-not-found, which only works on channels.
  programs.comma = {
    enable = true;
    enableZshIntegration = true;
  };

  # No system text editor: nano's module defaults to on and vim was the other
  # entry in systemPackages below -- both dropped. micro (home-manager,
  # modules/desktop.nix) is the editor Coru uses. nixpkgs points EDITOR at nano,
  # so repoint it rather than leave it dangling.
  programs.nano.enable = false;
  environment.variables.EDITOR = lib.mkForce "micro";

  # Admin/system tooling only -- btop, ripgrep, duf, ... are per-user in modules/.
  environment.systemPackages = with pkgs; [
    btrfs-progs
    nvme-cli
    smartmontools
    hdparm
    dmidecode
    pciutils
    usbutils
    hwinfo
    lm_sensors
    efibootmgr
    dosfstools
    exfatprogs
    ntfs3g
    gptfdisk
    rsync
    git
    curl
    wget
    jq
    file
    lsof
    strace
    psmisc
    tcpdump
    bind.dnsutils
    inetutils
    screen
    tmux

    # macOS compatibility layer (Wine-shaped) -- runs macOS binaries. A
    # system-level runtime, so it sits here with nix-ld/appimage rather than in
    # modules/gaming.nix. From the `rosemary` flake input (see pkgs/default.nix);
    # it keeps its prefixes in ~/.local/share/rosemary.
    rosemary
  ];

  # sshd is deliberately off: a listening sshd is a decision, not a default.
  #   services.openssh = { enable = true; settings.PasswordAuthentication = false; };
  #   networking.firewall.allowedTCPPorts = [ 22 ];
}
