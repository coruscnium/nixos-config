{ ... }:

# The desktop's panel, and nothing else -- the loader, kernel and boot console are
# shared policy (nixos/boot.nix).
{
  # Ultrawide boot menu. "stretched" needs the shapes to match, hence the pinned
  # resolution: one display only (UEFI GOP is a single framebuffer), and the
  # wallpaper is re-encoded to JPEG at that mode so Limine does a 1:1 blit.
  boot.loader.limine.style = {
    wallpapers = [ ../../boot/limine-wallpaper.jpg ];
    wallpaperStyle = "stretched";
    interface.resolution = "3440x1440";
  };
}
